AddCSLuaFile()

local ProjectileInfo = {}
ProjectileInfo.__index = ProjectileInfo
_G.ProjectileInfo = ProjectileInfo

-- Create the damage struct and effect data
local ImpactDamage = DamageInfo()
local ImpactEffect = EffectData()
local BounceEffect = EffectData()
local SplashEffect = EffectData()

local BounceOn = {
    [MAT_CONCRETE]    = true,
    [MAT_TILE]        = true,
    [MAT_PLASTIC]     = true,
    [MAT_SAND]        = false,
    [MAT_SNOW]        = false,
    [MAT_DIRT]        = true,
    [MAT_GRASS]       = false,
    [MAT_GLASS]       = true,
    [MAT_WOOD]        = true,
    [MAT_FLESH]       = false,
    [MAT_BLOODYFLESH] = false,
    [MAT_ALIENFLESH]  = false,
    [MAT_ANTLION]     = false,
    [MAT_METAL]       = true,
    [MAT_COMPUTER]    = true,
    [MAT_VENT]        = true
}

// Functions

function util.DistanceToLineFrac(Start, End, Point)
    local Dist = Start:Distance(End)

    local DistToLine, Nearest, Fraction = util.DistanceToLine(Start, End, Point)
    Fraction = math.Clamp(Fraction / Dist, 0, 1)

    return DistToLine, Nearest, Fraction
end

local function Spread(Normal, Degrees, Seed, Extra)
    Extra = Extra-1 or 0
    local correctDegrees = 1 - math.cos(math.rad(Degrees))
    local u = util.SharedRandom(Seed, 0, correctDegrees, Extra)
    local v = util.SharedRandom(Seed, 0, 1, Extra + 1)

    local phi = v * 2 * math.pi 
    local cosTheta = math.sqrt(1 - u)
    local sinTheta = math.sqrt(1 - cosTheta * cosTheta)
    local Final = Vector(cosTheta, math.cos(math.deg(phi)) * sinTheta, math.sin(math.deg(phi)) * sinTheta)
    Final:Rotate(Normal:Angle())
    return Final
end

local function Reflect(incident, normal)
    return incident - 2 * (incident:Dot(normal)) * normal
end

local function Squash(vec, planeNormal, scalar)
    return vec - (planeNormal * planeNormal:Dot(vec) * scalar)
end

local function Fallback(tbl, index, fallback)
    if not tbl then return end
    if not index then return end

    if tbl[index] == nil then
        tbl[index] = fallback
    end
end


-- Gets the player metatable
PlayerMeta = FindMetaTable("Player")

local VectorZERO = Vector(0, 0, 0)

local DefaultBulletInfo = {
    Attacker = NULL,
    Callback = nil,
    Damage = 1,
    Force = 1,
    Distance = 56756,
    HullSize = 0,
    Num = 1,
    Tracer = 1,
    AmmoType = "",
    Dir = VectorZERO,
    Spread = VectorZERO,
    Src = VectorZERO,
    IgnoreEntity = NULL
}

-- Creates a basic projectile structure

function ProjectileInfo:New()
    local self = {}

    local Default = DefaultBulletInfo
    self.BulletInfo = Default

    -- Projectile specific variables
    self.Position = VectorZERO
    self.LastPosition = VectorZERO
    self.InterpolatedPosition = VectorZERO
    self.Velocity = VectorZERO
    self.Forward = VectorZERO
    self.MoveTrace = {}
    self.TickCount = 0
    self.Attacker = NULL 
    self.First = true
    self.TimeSinceLastSimulation = 0
    self.TickLifetime = 0
    self.TicksSinceLastBounce = 0
    self.Cracked = false
    self.AwaitingNextHit = false

    -- Variables for the managers
    self.Manager = nil
    self.Index = 0

    return setmetatable(self, ProjectileInfo)
end

-- Setups the projectile structure
function ProjectileInfo:Setup(BulletInfo)
    for k,v in pairs(BulletInfo) do
        self.BulletInfo[k] = v
    end
    
    local Damage, AmmoType = self.BulletInfo.Damage, self.BulletInfo.AmmoType
    if Damage == 0 and (AmmoType ~= "" and AmmoType ~= nil) then
        self.AmmoID = game.GetAmmoID(AmmoType)
    elseif Damage == 0 and (AmmoType == nil or AmmoType == "") then
        self.BulletInfo.Damage = 10
    end

    self.Settings = self.BulletInfo.Settings or {}
    self.BulletInfo.Settings = nil

    Fallback(self.Settings, "Speed", 20000)
    Fallback(self.Settings, "Gravity", 1000)
    Fallback(self.Settings, "MaxBounceAngle", 0.3)
    Fallback(self.Settings, "ShouldBounce", true)
    Fallback(self.Settings, "EnableSounds", true)


    self.BulletInfo.Spread = nil
    self.Position = BulletInfo.Src
    self.InterpolatedPosition = self.Position
    self.TimeAtLastSimulation = UnPredictedCurTime()
    self.LastPosition = self.Position
    self.Velocity = BulletInfo.Dir * self.Settings.Speed
    self.Forward = self.Velocity:GetNormalized()
    self.Attacker = BulletInfo.Attacker
end

function ProjectileInfo:CalculateSpread(BulletInfo, Seed, Extra)
    if not BulletInfo.Spread then return end
    BulletInfo.Dir = Spread(BulletInfo.Dir, BulletInfo.Spread[1] * 90, Seed, Extra)
end

function ProjectileInfo:SetTickCount(TickCount)
    self.TickCount = TickCount
end

function ProjectileInfo:GetTickCount()
    return self.TickCount
end

function ProjectileInfo:GetSimulationTick()
    return self.TickLifetime
end

function ProjectileInfo:SetManager(Manager, Index)
    self.Manager = Manager
    self.Index = Index
end

function ProjectileInfo:GetManager()
    return self.Manager
end

function ProjectileInfo:Delete()
    self.Manager:RemoveProjectile(self)
    table.Empty(self)
end

function ProjectileInfo:InterpolatePositions()
    if self.AwaitingNextHit then
        self.InterpolatedPosition = self.Position
        return
    end
    
    local TimePassed = math.Clamp((UnPredictedCurTime() - self.TimeAtLastSimulation) / engine.TickInterval(), 0, 1)

    self.InterpolatedPosition = LerpVector(TimePassed, self.LastPosition, self.Position)
end


local _AmmoTypeCache = {}
function GetAmmoTypeDamage(AmmoID)
    -- Attempt to return a cached value first.
    if _AmmoTypeCache[AmmoID] then return _AmmoTypeCache[AmmoID] end
    -- Set the cached variable for appropriate ammo type.
    _AmmoTypeCache[AmmoID] = game.GetAmmoPlayerDamage(AmmoID)

    return _AmmoTypeCache[AmmoID]
end

function ProjectileInfo:CalculateDamage(Entity)
    if not self.AmmoID or self.AmmoID == "" then return self.BulletInfo.Damage end

    local Damage = GetAmmoTypeDamage(self.AmmoID)

    return Damage
end

function ProjectileInfo:FireBullet()
    if not self.MoveTrace.Hit then return end

    local HitEntity = self.MoveTrace.Entity
    if HitEntity and HitEntity:IsValid() and HitEntity ~= self.Attacker then
        local CalculatedDamage = self:CalculateDamage(HitEntity)

        local Attacker = self.Attacker
        local Inflictor = self.Attacker
        if self.Attacker:GetOwner():IsValid() then
            Attacker = self.Attacker:GetOwner()
        end
        if self.Attacker:IsPlayer() and self.Attacker:GetActiveWeapon():IsValid() then
            Inflictor = self.Attacker:GetActiveWeapon()
        end

        -- Setup damage
        local ImpactDamage = DamageInfo()
        ImpactDamage:SetDamageType(DMG_BULLET)
        ImpactDamage:SetDamage(CalculatedDamage)
        --ImpactDamage:SetDamageForce(self.Forward * self.BulletInfo.Force)
        ImpactDamage:SetAttacker(Attacker)
        ImpactDamage:SetInflictor(Inflictor)
        ImpactDamage:SetReportedPosition(self.MoveTrace.HitPos)

        -- Apply Force
        if SERVER then
            local Phys = HitEntity:GetPhysicsObjectNum(self.MoveTrace.PhysicsBone)

            if not Phys or not Phys:IsValid() then
                ImpactDamage:SetDamageForce((self.Forward * self.BulletInfo.Force * 1500) + Vector(0, 0, 500))
            else
                ImpactDamage:SetDamageForce(Vector(0, 0, 0))
                Phys:ApplyForceOffset(self.Forward * self.BulletInfo.Force * 300, self.MoveTrace.HitPos)
            end
        end

        -- Apply damage to entity
        HitEntity:DispatchTraceAttack(ImpactDamage, self.MoveTrace, self.Forward)
    end

    if not self.Manager:GetPrediction() or CLIENT then
        -- Setup impact effect
        ImpactEffect:SetDamageType(DMG_BULLET)
        ImpactEffect:SetEntity(HitEntity)
        ImpactEffect:SetOrigin(self.MoveTrace.HitPos + self.MoveTrace.Normal)
        ImpactEffect:SetStart(self.Position - self.MoveTrace.Normal * 4)
        ImpactEffect:SetSurfaceProp(self.MoveTrace.SurfaceProps)
        ImpactEffect:SetHitBox(self.MoveTrace.HitBox)
        ImpactEffect:SetNormal(self.MoveTrace.HitNormal)

        -- Apply effect
        util.Effect("Impact", ImpactEffect)
    end

    //-- Call callback
    //if self.BulletInfo.Callback then
    //    self.BulletInfo.Callback(self.Attacker, self.MoveTrace, ImpactDamage)
    //end
end

function ProjectileInfo:ShouldBounce()
    if not BounceOn[self.MoveTrace.MatType] then
        return false
    end

    if self.Velocity:LengthSqr() < (1000 ^ 2) then
        return false
    end

    if self.MoveTrace.Entity and self.MoveTrace.Entity:IsValid() then
        local EntityClass = self.MoveTrace.Entity:GetClass()
        if not (EntityClass == "prop_physics" or EntityClass == "worldspawn") then return false end
    end


    local Dot = self.MoveTrace.HitNormal:Dot(-self.Forward:GetNormalized())
    return (Dot < self.Settings.MaxBounceAngle) and (self.MoveTrace.Fraction ~= 0)
end

function ProjectileInfo:Simulate()
    local Settings = self.Settings
    local UpdateRate = engine.TickInterval()
    
    local Velocity = self.Velocity
    util.TraceLine({
        start = self.Position,
        endpos = self.Position + Velocity * UpdateRate,
        filter = self.Attacker,
        mask = MASK_SHOT,
        output = self.MoveTrace
    })


    self.LastPosition = self.Position
    self.Position = self.MoveTrace.HitPos
    self.Forward = Velocity:GetNormalized()

    -- Bounce
    self.TicksSinceLastBounce = self.TicksSinceLastBounce + 1
    if self.MoveTrace.Hit and Settings.ShouldBounce then
        local Fraction = (1 - self.MoveTrace.Fraction)
        local Hit = false
        local LastVelocity = Velocity
        for i=1, 16 do
            if not self:ShouldBounce() then break end

            self:OnBounce()
            LastVelocity = self.Velocity

            if not self.MoveTrace.Hit then break end

            util.TraceLine({
                start = self.Position,
                endpos = self.Position + self.Velocity * UpdateRate * Fraction,
                filter = self.Attacker,
                mask = MASK_SHOT,
                output = self.MoveTrace
            })
            self.Position = self.MoveTrace.HitPos
            self.LastPosition = self.Position

            Fraction = Fraction - self.MoveTrace.Fraction

            if Fraction <= 0 then break end
            self.MoveTrace.Hit = false
        end
        self.Forward = LastVelocity:GetNormalized()
    end
    
    if self.MoveTrace.Hit and not self.AwaitingNextHit then
        self.AwaitingNextHit = true
        self.MoveTrace.Hit = false
    end


    -- Apply gravity
    local Gravity = Vector(0, 0, -Settings.Gravity) * UpdateRate
    self.Velocity = self.Velocity + Gravity

    self.TimeAtLastSimulation = UnPredictedCurTime()
    self.First = self.TickLifetime < 1
    self.TickLifetime = self.TickLifetime + 1

    self:OnSimulate()
    self:SimulateWaterDrag()
end

local function PointContents(Pos, Content)
    return bit.band(util.PointContents(Pos), Content) == Content
end

local function BubbleTrail(Start, End, Count)
    for i=0, Count-1 do
        local Delta = (Count == 1) and 0.5 or i / (Count-1)
        local InterpolatedPosition = LerpVector(Delta, Start, End)

        effects.Bubbles(InterpolatedPosition + Vector(-6, -6, -6), InterpolatedPosition + Vector(6, 6, 6), 2, math.random() * 32, 64, 0)
    end
end

function ProjectileInfo:SimulateWaterDrag()
    local SpeedLoss = 0.5

    local MoveTrace = self.MoveTrace
    local InWater = PointContents(MoveTrace.StartPos, CONTENTS_WATER) or PointContents(MoveTrace.StartPos, CONTENTS_TRANSLUCENT)

    if InWater then
        local VelocityLength = self.Velocity:Length()
        self.Velocity = self.Velocity - (self.Velocity * SpeedLoss)
        if VelocityLength < 100 then
            self:Delete()
        end

        if VelocityLength > 2000 then
            local Normalized = VelocityLength * 0.0005
            BubbleTrail(MoveTrace.StartPos, MoveTrace.HitPos, 8)
        end
    end
end

function ProjectileInfo:OnSimulate()
    -- Do splash effects
    local MoveTrace = self.MoveTrace

    local InWater = PointContents(MoveTrace.HitPos, CONTENTS_WATER) or PointContents(MoveTrace.HitPos, CONTENTS_TRANSLUCENT)
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
            -- Setup splash effect
            SplashEffect:SetOrigin(WaterTrace.HitPos)
            SplashEffect:SetScale(6)

            -- Apply effect
            util.Effect("gunshotsplash", SplashEffect)
            util.Effect("waterripple", SplashEffect)
        end
    end
end

function ProjectileInfo:OnHit()
    -- Dont do anything if the bullet hit the sky
    if self.MoveTrace.HitSky then 
        self:Delete()
        return
    end

    -- Dont do anything if the attacker is no longer valid 
    if not self.Attacker or not self.Attacker:IsValid() then
        self:Delete()
        return
    end

    -- Impact sounds
    if CLIENT and self.Settings.EnableSounds and BounceOn[self.MoveTrace.MatType] then
        EmitSound("sonic_Crack.Distant", self.MoveTrace.HitPos, 0, CHAN_STATIC, 5, 160, 0, 150, 0)
    end

    -- Fire the bullet
    self:FireBullet()

    -- Delete the projectile
    self:Delete()
end

function ProjectileInfo:OnBounce()
    local SpeedLoss = 0.75--1 - (self.MoveTrace.HitNormal:Dot(-self.Forward))

    

    self.Velocity = Reflect(self.Velocity, self.MoveTrace.HitNormal) * SpeedLoss
    self.Cracked = false
    self.TicksSinceLastBounce = 0

    local HalfNormal = (self.Forward + self.MoveTrace.HitNormal):GetNormalized()
    BounceEffect:SetOrigin(self.Position)
    BounceEffect:SetNormal(HalfNormal)
    BounceEffect:SetMagnitude(1)
    BounceEffect:SetScale(1)
    util.Effect( "ElectricSpark", BounceEffect)

    -- Play bounce sound
    if CLIENT and self.Settings.EnableSounds then
        EmitSound("sonic_Crack.Distant", self.MoveTrace.HitPos, 0, CHAN_STATIC, 5, 160, 0, 255, 0)
    end
end

if CLIENT then
    // Rendering

    local GlowEffect = Material("sprites/orangecore2")
    local Tracer = Material("effects/tracer_middle")

    local r = 4
    local Quad = {Vector(0, r, r), Vector(0, r, -r), Vector(0, -r, -r), Vector(0, -r, r)}
    function ProjectileInfo:Render()
        local BulletSpeed = self.Velocity:Length() * engine.TickInterval()
        local IsAttackerPlayer = self.Attacker == LocalPlayer()

        local RenderTick = 3
        if self.TicksSinceLastBounce > RenderTick or not IsAttackerPlayer then

            -- Tracer
            render.SetMaterial(Tracer)
            if self.TicksSinceLastBounce < (RenderTick - 1) then
                render.DrawBeam(self.InterpolatedPosition, self.LastPosition, 3, 0, 1)
            else
                render.DrawBeam(self.InterpolatedPosition, self.InterpolatedPosition - self.Forward * BulletSpeed * 1, 3, 0, 1)
            end
        end

        if self.TicksSinceLastBounce > 1 then
            local EyePosition = EyePos()
            local BulletPosition = self.InterpolatedPosition
            local BulletForward = self.Forward
            
            local NewQuad = {}
            for k, Vert in pairs(Quad) do
                local Vert = Vector(Vert[1], Vert[2], Vert[3])
                
                local DirectionToBullet = (BulletPosition - EyePosition):GetNormalized()
            
                Vert:Rotate((-DirectionToBullet):Angle())
                
                local DotToBullet = 1 - (math.abs(DirectionToBullet:Dot(BulletForward)) * 0.75)

                Vert = Squash(Vert, BulletForward, -BulletSpeed * 0.05 / DotToBullet)
                Vert = Squash(Vert, DirectionToBullet, 1)
            
                NewQuad[k] = Vert + BulletPosition
            end
            render.SetMaterial(GlowEffect)
            render.DrawQuad(NewQuad[1], NewQuad[2], NewQuad[3], NewQuad[4])
        end
    end

    // Sounds
    function ProjectileInfo:Crack()
        if not self.Settings.EnableSounds then return end

        local LocalVelocity = self.Velocity - LocalPlayer():GetVelocity()
        local LocalSpeed = LocalVelocity:Length()

        local Eyepos = EyePos()

        if self.Position:DistToSqr(Eyepos) > 1500^2 then return end
        if self.Cracked then return end


        local Start, End = self.LastPosition, self.Position
        local DistanceToLine, Point, Fraction = util.DistanceToLineFrac(Start, End, Eyepos)

        local Distances = {
            {100, "sonic_Crack.Light", 1},
            {400, "sonic_Crack.Heavy", 1 - ((DistanceToLine / 400) * 0.5)},
            {1200, "sonic_Crack.Medium", 1 - (DistanceToLine / 1200)}
        }
        if not self.First and Fraction < 1 and LocalSpeed > 10000 then
            for i=1, #Distances do
                local TheFuck = Distances[i]
                if DistanceToLine < TheFuck[1] then
                    self.Cracked = true
                    local Volume = TheFuck[3]
                    local SoundPath = TheFuck[2]
                    EmitSound(SoundPath, Point, 0, CHAN_AUTO, Volume, 150, 0, 100, 0)
                    break
                end
            end
        end
    end
end

/////////////////////////////////////////////////////////////////////////////////////////////////////

local C_ProjectileManager = {}
C_ProjectileManager.__index = C_ProjectileManager
_G.C_ProjectileManager = C_ProjectileManager


-- Create a projectile manager
function C_ProjectileManager:New()
    local self = {}

    self.Projectiles = {}
    self.AttachedEntity = NULL 
    self.ShouldPredict = true
    self.Index = 0

    return setmetatable(self, C_ProjectileManager)
end

function C_ProjectileManager:EnablePrediction()
    self.ShouldPredict = true
end

function C_ProjectileManager:DisablePrediction()
    self.ShouldPredict = false
end

function C_ProjectileManager:GetPrediction()
    return self.ShouldPredict
end

function C_ProjectileManager:AttachToPlayer(Player)
    -- Sets the manager for the player, returns false if failed to assign manager
    local WasAssigned = Player:SetProjectileManager(self)

    -- Failed to assign manager
    if not WasAssigned then return end

    self.AttachedEntity = Player
end

-- Gets the entity the manager is attached to
function C_ProjectileManager:GetAttachedEntity()
    return self.AttachedEntity
end

-- Checks if the manager is attached to an entity
function C_ProjectileManager:IsAttachedToEntity()
    return self.AttachedEntity ~= nil and self.AttachedEntity ~= NULL
end

-- Gets projectiles from the list
function C_ProjectileManager:GetProjectiles()
    return self.Projectiles
end

-- Add projectile to the list
function C_ProjectileManager:AddProjectile(_ProjectileInfo)
    local Index = table.insert(self.Projectiles, _ProjectileInfo)
    _ProjectileInfo:SetManager(self, Index)
end

-- Removes projectile from the list
function C_ProjectileManager:RemoveProjectile(_ProjectileInfo)
    self.Projectiles[_ProjectileInfo.Index] = nil
end

function C_ProjectileManager:CreateProjectile(BulletInfo)
    -- Prevent prediction from the engine
    if self:GetPrediction() and not IsFirstTimePredicted() then return end

    -- Create a new projectile structure
    local Projectile = ProjectileInfo:New()

    -- Setup the projectile structure
    Projectile:Setup(BulletInfo)

    -- Get the entity which the manager is attached to
    local AttachedEntity = self:GetAttachedEntity()
    if AttachedEntity:IsPlayer() then
        -- Set attacker of the projectile in case it is not set
        --Projectile.BulletInfo.Attacker = AttachedEntity

        if self:GetPrediction() and GetPredictionPlayer() == AttachedEntity then
            -- Get the current command
            local CUserCmd = AttachedEntity:GetCurrentCommand()

            -- Set the tick at which the bullet was fired (allows for mostly accurate lag compensation)
            if CUserCmd then
                Projectile:SetTickCount(CUserCmd:TickCount())
            else
                Projectile:SetTickCount(engine.TickCount())
            end
        else
            -- Cannot use current command when not in a prediction so we use the server tick count
            Projectile:SetTickCount(engine.TickCount())
        end
    else 
        Projectile:SetTickCount(engine.TickCount())
    end

    -- Call the internal hook function
    self:OnCreateProjectile(Projectile.BulletInfo)

    -- Add projectile to the manager's projectile list
    self:AddProjectile(Projectile)
    return Projectile
end

function C_ProjectileManager:OnCreateProjectile(BulletInfo)
    -- Hi
end

if SERVER then
    function C_ProjectileManager:OnSetupMove(Player, CMoveData, CUserCmd)
        if not self:GetPrediction() then return end
        if not IsFirstTimePredicted() then return end

        C_LagCompensationManager:StartLagCompensation(Player)
        for _, Projectile in next, self:GetProjectiles() do
            
            local TargetTick = Projectile:GetTickCount() + Projectile:GetSimulationTick() - 1
            C_LagCompensationManager:BacktrackTo(TargetTick)
            Projectile:Simulate()

            if table.IsEmpty(Projectile) then continue end
            
            C_HitboxSystem:QueryRaycast(Projectile.MoveTrace, function()
                Projectile:OnHit()
            end)
        end
        C_LagCompensationManager:EndLagCompensation()
    end
else
    function C_ProjectileManager:OnSetupMove(Player, CMoveData, CUserCmd)
        if not self:GetPrediction() then return end
        if not IsFirstTimePredicted() then return end
    
        for _, Projectile in next, self:GetProjectiles() do

            Projectile:Simulate()

            if table.IsEmpty(Projectile) then continue end
            
            if Projectile.MoveTrace.Hit then
                Projectile:OnHit()
            end
        end

    end
end

function C_ProjectileManager:OnSetupMoveUnpredicted()
    if self:GetPrediction() then return end
    for _, Projectile in next, self:GetProjectiles() do

        Projectile:Simulate()

        if table.IsEmpty(Projectile) then continue end

        if Projectile.MoveTrace.Hit then
            Projectile:OnHit()
        end
    end
end


if CLIENT then
    function C_ProjectileManager:InterpolateProjectilePositions()
        for _, Projectile in next, self:GetProjectiles() do
            Projectile:InterpolatePositions()
        end
    end

    function C_ProjectileManager:RenderProjectiles()
        for _, Projectile in next, self:GetProjectiles() do
            Projectile:Render()
        end
    end

    function C_ProjectileManager:CrackProjectiles()
        for _, Projectile in next, self:GetProjectiles() do
            Projectile:Crack()
        end
    end
end

/////////////////////////////////////////////////////////////////////////////////////////////////////

function PlayerMeta:GetProjectileManager()
    return self.ProjectileManager
end

function PlayerMeta:SetProjectileManager(Manager)
    -- Only allow one manager per player
    -- The manager was not assigned
    if self:GetProjectileManager() ~= nil then return false end
    
    self.ProjectileManager = Manager

    -- The manager was assigned
    return true 
end

function PlayerMeta:RemoveProjectileManager()
    self.ProjectileManager = nil
end
