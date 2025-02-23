AddCSLuaFile()

local UNIT = include("ballistica/core/unit.lua")

local PROJECTILE = {}
PROJECTILE.__index = PROJECTILE

PROJECTILE.Base = ""
PROJECTILE.Name = "base_projectile"

local ImpactDamage = DamageInfo()
local ImpactEffect = EffectData()
local BloodEffect = EffectData()
local SplashEffect = EffectData()

local VectorZERO = Vector(0, 0, 0)


local ConvarCache = {}
local function GetConVarCached(ConvarName)
    if ConvarCache[ConvarName] == nil then
        local ConVar = GetConVar(ConvarName)
        ConvarCache[ConvarName] = ConVar
    end

    return ConvarCache[ConvarName]
end

local function PointContents(Pos, Content)
    return bit.band(util.PointContents(Pos), Content) == Content
end

local function Spread(Normal, Degrees, Seed, Extra)
    Extra = Extra-1 or 0
    local correctDegrees = 1 - math.cos(math.rad(Degrees))
    local u = (util.SharedRandom(Seed, 0, 1, Extra) ^ 2) * correctDegrees
    local v = util.SharedRandom(Seed, 0, 1, Extra + 1)

    local phi = v * 2 * math.pi 
    local cosTheta = math.sqrt(1 - u)
    local sinTheta = math.sqrt(1 - cosTheta * cosTheta)
    local Final = Vector(cosTheta, math.cos(math.deg(phi)) * sinTheta, math.sin(math.deg(phi)) * sinTheta)
    Final:Rotate(Normal:Angle())
    return Final
end

// BUG!!!
// The bubbles are books on gm_novenka (wtf?)
local function BubbleTrail(Start, End, Count)
    for i=0, Count-1 do
        local Delta = (Count == 1) and 0.5 or i / (Count-1)
        local InterpolatedPosition = LerpVector(Delta, Start, End)

        effects.Bubbles(InterpolatedPosition + Vector(-6, -6, -6), InterpolatedPosition + Vector(6, 6, 6), 2, math.random() * 32, 64, 0)
    end
end

function util.DistanceToLineFrac(Start, End, Point)
    local Dist = Start:Distance(End)

    local DistToLine, Nearest, Fraction = util.DistanceToLine(Start, End, Point)
    Fraction = math.Clamp(Fraction / Dist, 0, 1)

    return DistToLine, Nearest, Fraction
end

local function Fallback(tbl, index, fallback)
    if not tbl then return end
    if not index then return end

    if tbl[index] == nil then
        tbl[index] = fallback
    end
    return tbl[index]
end

/////////////////////////////////////////////////////////////

-- Initialize variables
PROJECTILE.Valid = true
PROJECTILE.Attacker = NULL
PROJECTILE.BulletInfo = {}
PROJECTILE.MoveTrace = {}
--PROJECTILE.Trajectory = {}
PROJECTILE.Position = VectorZERO
PROJECTILE.LastPosition = VectorZERO
PROJECTILE.InterpolatedPosition = VectorZERO
PROJECTILE.Velocity = VectorZERO
PROJECTILE.Forward = VectorZERO
PROJECTILE.Index = 0
PROJECTILE.StartTime = 0
PROJECTILE.TimeAtLastSimulation = 0
PROJECTILE.TickCount = 0
PROJECTILE.TickLifetime = 0
PROJECTILE.Deleting = false
PROJECTILE.AmmoID = ""

PROJECTILE.Damage = 10
PROJECTILE.Speed = UNIT.FT_TO_HAMMER(2350) -- FPS
PROJECTILE.MinimumLethalSpeed = UNIT.FT_TO_HAMMER(500)
PROJECTILE.MinimumSpeed = UNIT.FT_TO_HAMMER(50)
PROJECTILE.Gravity = 1000

PROJECTILE.Weight = 0.005 -- in kg
PROJECTILE.AirDensity = 1.225 -- in kg/m^3
PROJECTILE.WaterDensity = 50 -- in kg/m^3 (50 is too low to be realistic but due to limitations of the simulation it breaks down at 998)
PROJECTILE.Diameter = 5 -- in mm
PROJECTILE.DragCoefficient = 0.47 -- (unitless, it is derived from many other variables)






function PROJECTILE:New(BulletInfo)
    local self = setmetatable({}, self)

    self.BulletInfo = {}
    for k,v in pairs(BulletInfo) do
        self.BulletInfo[k] = v
    end

    self:Initialize()

    return self
end

function PROJECTILE:Initialize()
    if self.BulletInfo.Speed == 0 then
        self.BulletInfo.Speed = nil
    end

    self.MoveTrace = {}
    self.Filter = {self.BulletInfo.Attacker}
    self.BulletInfo.Spread = nil
    self.Position = self.BulletInfo.Src
    self.LastPosition = self.Position
    self.InterpolatedPosition = self.Position
    self.TimeAtLastSimulation = SysTime()
    self.StartTime = UnPredictedCurTime()
    self.Velocity = self.BulletInfo.Dir * (self.BulletInfo.Speed or self.Speed)
    self.Forward = self.Velocity:GetNormalized()
    self.Attacker = self.BulletInfo.Attacker
end

function PROJECTILE:AddFilter(EntityOrTable)
    if not IsValid(EntityOrTable) then return end
    if type(EntityOrTable) == "table" then
        table.Add(self.Filter, EntityOrTable)
        return
    end
    table.insert(self.Filter, EntityOrTable)
end

function PROJECTILE:ApplyForce(Force)
    self.Velocity = self.Velocity + Force / self.Weight 
end

function PROJECTILE:GetPos()
    return self.InterpolatedPosition
end

function PROJECTILE:GetRealPos()
    return self.Position
end

function PROJECTILE:GetUpdateRate()
    local UpdateRate
    if game.SinglePlayer() or CLIENT then
        UpdateRate = engine.TickInterval()
    elseif SERVER then
        UpdateRate = engine.TickInterval() * GetConVarCached("host_timescale"):GetFloat()
    end
    return UpdateRate
end

function PROJECTILE:SetTickCount(TickCount)
    self.TickCount = TickCount
end

function PROJECTILE:GetTickCount()
    return self.TickCount
end

function PROJECTILE:GetSimulationTick()
    return self.TickLifetime
end

function PROJECTILE:GetTargetCompensationTick()
    return self:GetTickCount() + self:GetSimulationTick() - 1
end

function PROJECTILE:GetLifetime()
    return UnPredictedCurTime() - self.StartTime
end

function PROJECTILE:Remove()
    -- add this, remove from projectile table!
    table.Empty(self)
    self.Valid = false
end

function PROJECTILE:Delete()
    self.Deleting = true
end

function PROJECTILE:InterpolatePositions()
    --if self.Deleting then
    --    self.InterpolatedPosition = self.MoveTrace.Position
    --    return
    --end
    local CurrentTime = SysTime()

    local TimeScale = GetConVarCached("host_timescale"):GetFloat()
    local TimePassed = math.Clamp(((CurrentTime - self.TimeAtLastSimulation) / engine.TickInterval() * TimeScale), 0, 1)
    self.InterpolatedPosition = LerpVector(TimePassed, self.LastPosition, self.Position)
end

function PROJECTILE:IsSupersonic()
    return self.Velocity:Length() > UNIT.FT_TO_HAMMER(1125)
end

function PROJECTILE:IsLethal()
    return self.Velocity:Length() > self.MinimumLethalSpeed 
end

function PROJECTILE:DoImpactEffect(Trace)
    local Trace = Trace or self.MoveTrace
    --if not Trace.Hit then return end
    
    ImpactEffect:SetDamageType(DMG_PREVENT_PHYSICS_FORCE)
    ImpactEffect:SetEntity(Trace.Entity)
    ImpactEffect:SetOrigin(Trace.HitPos + Trace.Normal)
    ImpactEffect:SetStart(Trace.HitPos - Trace.Normal)
    ImpactEffect:SetNormal(Trace.Normal)
    ImpactEffect:SetSurfaceProp(Trace.SurfaceProps)
    ImpactEffect:SetHitBox(Trace.HitBox)

    -- Apply effect
    util.Effect("Impact", ImpactEffect)
end

function PROJECTILE:FireBullet(OptionalTrace)
    local Trace = OptionalTrace or self.MoveTrace
    if not Trace.Hit then return end
    if not self:IsLethal() then return end

    
    local HitEntity = Trace.Entity

    --if SERVER and IsValid(HitEntity) and HitEntity ~= self.Attacker then
    if IsValid(HitEntity) and IsValid(self.Attacker) and HitEntity ~= self.Attacker then
        local Attacker = self.Attacker
        local Inflictor = self.Attacker

        if IsValid(self.Attacker:GetOwner()) then
            Attacker = self.Attacker:GetOwner()
        end
        if self.Attacker:IsPlayer() and IsValid(self.Attacker:GetActiveWeapon()) then
            Inflictor = self.Attacker:GetActiveWeapon()
        end

        local Pos, Normal, HitGroup, Trace2 = Trace.HitPos, Trace.Normal, Trace.HitGroup, table.Copy(Trace) -- fuckled copy yurr
        timer.Simple(0, function()
            if not IsValid(HitEntity) then return end
            -- Setup damage
            ImpactDamage:SetDamageType(DMG_PREVENT_PHYSICS_FORCE + DMG_BULLET)
            ImpactDamage:SetDamage(self.Damage)
            ImpactDamage:SetReportedPosition(Pos)
            ImpactDamage:SetDamageForce(Normal)
    
            if IsValid(Attacker) then 
                ImpactDamage:SetAttacker(Attacker)
                ImpactDamage:SetInflictor(Inflictor)
            end

            if HitGroup == HITGROUP_HEAD then
                ImpactDamage:ScaleDamage(5)
            end
    
            if HitGroup == HITGROUP_CHEST then
                ImpactDamage:ScaleDamage(1.5)
            end

            -- Apply damage to entity
            HitEntity:DispatchTraceAttack(ImpactDamage, Trace2, Normal)
        end)

        -- force
        if SERVER then
            local Phys = HitEntity:GetPhysicsObjectNum(self.MoveTrace.PhysicsBone)

            if IsValid(Phys) then
                Phys:ApplyForceOffset(self.Velocity * self.Weight * 2, Trace.HitPos)
            end
        end
    end

    if CLIENT then
        self:DoImpactEffect()
    end
end

function PROJECTILE:Simulate()
    local UpdateRate = self:GetUpdateRate()
    
    if self.Virtual then
        self:VirtualRay(false)
    else
        util.TraceLine({
            start = self.Position,
            endpos = self.Position + self.Velocity * UpdateRate,
            filter = self.Filter,
            mask = MASK_SHOT,
            output = self.MoveTrace
        })
    end

    if self.Position == self.MoveTrace.HitPos then
        self:Delete()
        return
    end

    self.LastPosition = self.Position
    self.Position = self.MoveTrace.HitPos
    self.Forward = self.Velocity:GetNormalized()
    
    self:OnSimulate()


    local InWater = PointContents(self.Position, CONTENTS_WATER) or PointContents(self.Position, CONTENTS_SLIME)

    -- Apply gravity
    local Gravity = Vector(0, 0, -self.Gravity) * UpdateRate
    self.Velocity = self.Velocity + Gravity


    -- Apply drag
    local p = self.AirDensity -- density
    if InWater then
        p = self.WaterDensity
    end

    local Speed = self.Velocity:Length()
    local u = UNIT.HAMMER_TO_M(Speed * UpdateRate) -- speed
    local A = math.pi * self.Diameter * .5 ^ 2 -- area
    local Cd = self.DragCoefficient -- sphere drag coef

    local Fd = -self.Forward * math.min(Speed, .5 * p * u^2 * Cd * A)

    self.Velocity = self.Velocity + Fd


    self.TimeAtLastSimulation = SysTime()
    self.TickLifetime = self.TickLifetime + 1
 
    if self.Velocity:LengthSqr() < self.MinimumSpeed ^ 2 then
        self:Delete()
        return
    end

    if self.Virtual and (UnPredictedCurTime() - self.VirtualSince) >= self.VirtualLifetime then
        self:Delete()
        return
    end

    if self.MoveTrace.HitPos == self.MoveTrace.StartPos then
        self:Delete()
        return
    end
end

function PROJECTILE:OnSimulate()
    self:SimulateWaterEffects()
end

function PROJECTILE:SimulateWaterEffects()
    -- Do splash effects
    local MoveTrace = self.MoveTrace

    local IsSlime = PointContents(MoveTrace.HitPos, CONTENTS_SLIME)
    local InWater = PointContents(MoveTrace.HitPos, CONTENTS_WATER) or IsSlime // CONTENTS_TRANSLUCENT
    if InWater and CLIENT then
        local WaterTrace = {}
        util.TraceLine({
            start = self.LastPosition,
            endpos = MoveTrace.HitPos,
            filter = self.Attacker,
            mask = MASK_WATER,
            output = WaterTrace
        })

        if WaterTrace.Hit and not WaterTrace.StartSolid then
            local Flags = IsSlime and 1 or 2

            -- Setup splash effect
            SplashEffect:SetOrigin(WaterTrace.HitPos)
            SplashEffect:SetSurfaceProp(WaterTrace.SurfaceProps)
            SplashEffect:SetFlags(Flags)
            SplashEffect:SetScale(4)

            -- Apply effect
            util.Effect("gunshotsplash", SplashEffect)
        end
    end
end

function PROJECTILE:OnHit()
    -- Dont do anything if the bullet hit the sky
    if self.MoveTrace.HitSky then 
        self:Delete()
        return
    end

    -- Dont do anything if the attacker is no longer valid 
    if not IsValid(self.Attacker) then
        self:Delete()
        return
    end

    -- Fire the bullet
    self:FireBullet()

    -- Delete the projectile
    self:Delete()
end

local Green = Color(0, 255, 0, 255)
local Yellow = Color(255, 255, 0, 32)
local Red = Color(255, 0, 0, 255)
local Lifetime = 0
function PROJECTILE:Render()
    if self.Attacker:IsPlayer() and self.TickLifetime == 0 then return end
    
    render.SetColorMaterial()
    render.DrawSphere(self:GetPos(), 6, 30, 30, Green)
    render.DrawSphere(self:GetRealPos(), 12, 30, 30, Yellow)
    render.DrawBeam(self:GetPos(), self:GetPos() + self.Forward * 32, 1, 0, 1, Red)
end

return PROJECTILE
