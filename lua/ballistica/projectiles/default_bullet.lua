AddCSLuaFile()

local UNIT = include("ballistica/core/unit.lua")

local PROJECTILE = {}
PROJECTILE.__index = PROJECTILE
PROJECTILE.Base = "base_projectile"
PROJECTILE.Name = "default_bullet"

local HARDNESS = {
    SOFT = 1,
    FIRM = 2,
    HARD = 3
}

-- Initialize variables
PROJECTILE.BouncedThisTick = false
PROJECTILE.Cracked = false
PROJECTILE.Speed = UNIT.FT_TO_HAMMER(2000)
PROJECTILE.MinimumSpeed = UNIT.FT_TO_HAMMER(0)
PROJECTILE.MaxBounceAngle = 0.1
PROJECTILE.Virtual = false
PROJECTILE.VirtualLifetime = 1
PROJECTILE.VirtualSince = 0

PROJECTILE.PenetrationMultiplier = 1


PROJECTILE.CoreHardness = HARDNESS.FIRM -- lead
PROJECTILE.Diameter = 9 -- in mm
PROJECTILE.Weight = 0.007 -- in kg
PROJECTILE.DragCoefficient = 0.45 -- (unitless, it is derived from many other variables)


PROJECTILE.TracerColor = Color(255, 240, 180)

-- Test
--PROJECTILE.Gravity = 0
--PROJECTILE.Speed = UNIT.FT_TO_HAMMER(5)
--PROJECTILE.MinimumSpeed = 0
--PROJECTILE.Drag = 0
--PROJECTILE.WaterDrag = 0
--PROJECTILE.MaxBounceAngle = 0.2

local ImpactEffect = EffectData()
local BounceEffect = EffectData()

local VectorZERO = Vector(0, 0, 0)

local MaterialInfo = {
    [-1] = {
        Hardness = HARDNESS.SOFT,
        PenetrationCoef = 1
    },
    [MAT_CONCRETE]    = {
        Hardness = HARDNESS.HARD,
        PenetrationCoef = 0.02
    },
    [MAT_TILE]    = {
        Hardness = HARDNESS.HARD,
        PenetrationCoef = 0.02
    },
    [MAT_PLASTIC]    = {
        Hardness = HARDNESS.SOFT,
        PenetrationCoef = 0.15
    },
    [MAT_SAND]    = {
        Hardness = HARDNESS.SOFT,
        PenetrationCoef = 0.04
    },
    [MAT_SNOW]    = {
        Hardness = HARDNESS.SOFT,
        PenetrationCoef = 0.2
    },
    [MAT_DIRT]    = {
        Hardness = HARDNESS.SOFT,
        PenetrationCoef = 0.03
    },
    [MAT_GRASS]    = {
        Hardness = HARDNESS.SOFT,
        PenetrationCoef = 0.03
    },
    [MAT_GLASS]    = {
        Hardness = HARDNESS.FIRM,
        PenetrationCoef = 0.03
    },
    [MAT_WOOD]    = {
        Hardness = HARDNESS.SOFT,
        PenetrationCoef = 0.1
    },
    [MAT_FLESH]    = {
        Hardness = HARDNESS.SOFT,
        PenetrationCoef = 0.1
    },
    [MAT_BLOODYFLESH]    = {
        Hardness = HARDNESS.SOFT,
        PenetrationCoef = 0.1
    },
    [MAT_ALIENFLESH]    = {
        Hardness = HARDNESS.SOFT,
        PenetrationCoef = 0.09
    },
    [MAT_ANTLION]    = {
        Hardness = HARDNESS.FIRM,
        PenetrationCoef = 0.05
    },
    [MAT_METAL]    = {
        Hardness = HARDNESS.HARD,
        PenetrationCoef = 0.02
    },
    [MAT_COMPUTER]    = {
        Hardness = HARDNESS.FIRM,
        PenetrationCoef = 0.3
    },
    [MAT_VENT]    = {
        Hardness = HARDNESS.FIRM,
        PenetrationCoef = 0.07
    }
}

local function Get(table, index)
    local indexed = table[index]
    if indexed == nil then
        return table[-1]
    end
    return indexed
end

local function PointContents(Pos, Content)
    return bit.band(util.PointContents(Pos), Content) == Content
end

function util.DistanceToLineFrac(Start, End, Point)
    local Dist = Start:Distance(End)

    local DistToLine, Nearest, Fraction = util.DistanceToLine(Start, End, Point)
    Fraction = math.Clamp(Fraction / Dist, 0, 1)

    return DistToLine, Nearest, Fraction
end

local function Reflect(incident, normal)
    return incident - 2 * (incident:Dot(normal)) * normal
end

local function Squash(vec, planeNormal, scalar)
    return vec - (planeNormal * planeNormal:Dot(vec) * scalar)
end

local function ClampVectorLength(Vec, Min, Max)
    return Vec:GetNormalized() * math.Clamp(Vec:Length(), Min, Max)
end

local ConvarCache = {}
local function GetConVarCached(ConvarName)
    if ConvarCache[ConvarName] == nil then
        local ConVar = GetConVar(ConvarName)
        ConvarCache[ConvarName] = ConVar
    end

    return ConvarCache[ConvarName]
end

/////////////////////////////////////////////////////////////

function PROJECTILE:Initialize()
    PROJECTILE.BaseClass.Initialize(self)
    self.GlowColor = Color(self.TracerColor.r, self.TracerColor.g, self.TracerColor.b, 1)

    if CLIENT then
        self.PixVis = util.GetPixelVisibleHandle()
    end
end

function PROJECTILE:MakeVirtual()
    self.Virtual = true 
    self.VirtualSince = UnPredictedCurTime()

    self.MoveTrace.Hit = false
    self:VirtualRay(true)
end

function PROJECTILE:VirtualRay(Recast)
    local UpdateRate = self:GetUpdateRate()
    local Start, End, Normal

    if Recast then
        Start = self.MoveTrace.StartPos
        End = self.MoveTrace.StartPos + (self.MoveTrace.HitPos - self.MoveTrace.StartPos) / self.MoveTrace.Fraction
        Normal = (End - Start):GetNormalized()

        self.LastPosition = self.MoveTrace.StartPos
        self.Position = End
    else
        Start = self.Position
        End = self.Position + self.Velocity * UpdateRate
        Normal = (End - Start):GetNormalized()
    end

    self.MoveTrace.Fraction = 1
    self.MoveTrace.Hit = false
    self.MoveTrace.StartPos = Start
    self.MoveTrace.HitPos = End
    self.MoveTrace.Normal = Normal
end

function PROJECTILE:OnHit()
    -- Dont do anything if the bullet hit the sky
    if self.MoveTrace.HitSky then 
        self:MakeVirtual()
        --self:Delete()
        return
    end

    -- Dont do anything if the attacker is no longer valid 
    if not self.Attacker or not self.Attacker:IsValid() then
        self:Delete()
        return
    end

    -- Impact sounds
    if CLIENT then
        --EmitSound("sonic_Crack.Distant", self.MoveTrace.HitPos, 0, CHAN_STATIC, 5, 160, 0, 150, 0)
    end

    -- Fire the bullet
    self:FireBullet()

    -- Delete the projectile
    self:Delete()
end

function PROJECTILE:Crack()
    if not CLIENT then return end
    if self.Cracked then return end


    local Eyepos = EyePos()
    if self.Position:DistToSqr(Eyepos) > 1600^2 then return end

    local Start, End = self.LastPosition, self.Position
    local DistanceToLine, Point, Fraction = util.DistanceToLineFrac(Start, End, Eyepos)
    

    if self.TickLifetime <= 1 or Fraction >= 1 or self.BouncedThisTick then return end

    if self:IsSupersonic() then
        local Point = Point - self.Forward * 32
        if DistanceToLine < 100 then
            self.Cracked = true
            debugoverlay.Sphere(Point, 6, 0.1, Color(255, 0, 0, 0), false)
    
            local Volume = 1
            local Pitch = math.random(100, 120)

            EmitSound("sonic_Crack.Light", Point, 0, CHAN_AUTO, Volume, 150, 0, Pitch, 0)
            EmitSound("sonic_Crack.Supersonic", Point, 0, CHAN_AUTO, Volume, 150, 0, Pitch, 0)
           
            return
        end
    
        if DistanceToLine < 2000 then
            self.Cracked = true
            debugoverlay.Sphere(Point, 6, 0.1, Color(0, 255, 0, 0), false)
    
            local Volume = 1 - (DistanceToLine * 0.000625 * 1)
            local Pitch = math.random(80, 100)

            EmitSound("sonic_Crack.Supersonic", Point, 0, CHAN_AUTO, Volume, 150, 0, Pitch, 0)

            return
        end
    elseif self:IsLethal() then
        local Point = Point - self.Forward * 64
        if DistanceToLine < 100 then
            self.Cracked = true
            debugoverlay.Sphere(Point, 6, 0.1, Color(255, 0, 0, 0), false)
    
            local Volume = 1
            local Pitch = math.random(100, 110)

            EmitSound("sonic_Crack.Heavy", Point, 0, CHAN_AUTO, Volume, 150, 0, Pitch + 50, 0)
            EmitSound("sonic_Crack.Subsonic", Point, 0, CHAN_AUTO, Volume, 150, 0, Pitch, 0)
           
            return
        end
    
        if DistanceToLine < 500 then
            self.Cracked = true
            debugoverlay.Sphere(Point, 6, 0.1, Color(0, 255, 0, 0), false)
    
            local Volume = 1 - (DistanceToLine * 0.000625 * 3.2)
            local Pitch = math.random(90, 100)

            EmitSound("sonic_Crack.Subsonic", Point, 0, CHAN_AUTO, Volume, 150, 0, Pitch, 0)

            return
        end
    end
end

function PROJECTILE:ShouldBounce()
    if self.MoveTrace.HitSky then return false end

    -- Self explanatory
    if self.CoreHardness > Get(MaterialInfo, self.MoveTrace.MatType).Hardness then
        return false
    end

    -- Dont bounce if the speed is not high enough
    if self.Velocity:LengthSqr() < (5000 ^ 2) then
        --return false
    end

    -- Dont bounce on anything other than props and world
    if self.MoveTrace.Entity and self.MoveTrace.Entity:IsValid() then
        local EntityClass = self.MoveTrace.Entity:GetClass()
        if not (EntityClass == "prop_physics" or EntityClass == "worldspawn") then return false end
    end

    -- Dont bounce if the angle of attack is not shallow enough
    local Dot = self.MoveTrace.HitNormal:Dot(-self.Forward:GetNormalized())
    return (Dot < self.MaxBounceAngle) --and (self.MoveTrace.Fraction ~= 0)
end

function PROJECTILE:OnBounce()
    local forward = self.Velocity:GetNormalized()
    local SpeedLoss = (1 - (self.MoveTrace.HitNormal:Dot(-forward))) * 0.2

    self.Velocity = Reflect(self.Velocity, self.MoveTrace.HitNormal * 1) * SpeedLoss
    self.Cracked = false
    self.DragCoefficient = 1.08

    local HalfNormal = (forward + self.MoveTrace.HitNormal):GetNormalized()
    BounceEffect:SetOrigin(self.Position)
    BounceEffect:SetNormal(HalfNormal)
    BounceEffect:SetMagnitude(1)
    BounceEffect:SetScale(0.05)
    util.Effect( "ElectricSpark", BounceEffect)

    if CLIENT then
        local Size = 64
        local Light = DynamicLight(100000 + self.Index)
        Light.pos = self.Position --+ self.MoveTrace.HitNormal * Size * 0.5
        Light.r = 230
        Light.g = 230
        Light.b = 255
        Light.brightness = 4
        Light.decay = 0
        Light.size = 32
        Light.dietime = CurTime() + 0.1

        EmitSound("sonic_Crack.Distant", self.Position, 0, CHAN_STATIC, 5, 160, 0, 255, 0)
        if math.random() > 0.5 then
            EmitSound("sonic_Crack.Ricochet", self.Position, 0, CHAN_AUTO, 1, 80, 0, 100, 0)
        end
    end
end

function PROJECTILE:Bounce()
    self.BouncedThisTick = false

    local FractionLeft = (1 - self.MoveTrace.Fraction)
    local LastVelocity = self.Velocity
    local UpdateRate = self:GetUpdateRate()

    local lim = 0
    while FractionLeft > 0 and lim < 64 do
        if not self:ShouldBounce() then break end

        self:OnBounce()

        local Difference = self.Velocity:Length() / LastVelocity:Length()

        FractionLeft = FractionLeft * Difference

        util.TraceLine({
            start = self.Position,
            endpos = self.Position + self.Velocity * UpdateRate * FractionLeft,
            filter = self.Attacker,
            mask = MASK_SHOT,
            output = self.MoveTrace
        })

        self.Position = self.MoveTrace.HitPos
        self.Forward = self.Velocity:GetNormalized()

        FractionLeft = FractionLeft - self.MoveTrace.Fraction
        LastVelocity = self.Velocity

        self.MoveTrace.Hit = false
        self.BouncedThisTick = true
        if FractionLeft <= 0 then break end
        lim = lim + 1
    end
    return self.BouncedThisTick
end


local function VisualizeTrace(Trace, col)
    if CLIENT then return end
    local col = col or Color(255, 255, 255, 0)


    debugoverlay.Sphere(Trace.StartPos, 1, 4, col, true)
    debugoverlay.Sphere(Trace.HitPos, 2, 4, col, true)

    debugoverlay.Line(Trace.HitPos, Trace.StartPos, 4, col, true)
end

function PROJECTILE:PenetrateRayStep(Trc, TrcLength, Direction, Depth)
    if not Trc.Hit then return 0, 0 end
    local DistanceTravelled = TrcLength * Trc.Fraction
    
    local DepthTrace1 = {}
    local TestDepth = {}
    local Exception = false
    local Dist = 0
    if Trc.HitWorld then
        util.TraceLine({
            start = Trc.HitPos + (Direction * 1),
            --start = Trc.HitPos - (Trc.HitNormal * 1),
            endpos = Trc.HitPos + (Direction * Depth),
            filter = Trc.Entity,
            mask = MASK_SOLID_BRUSHONLY,
            output = DepthTrace1
        })

        util.TraceLine({
            start = DepthTrace1.HitPos,
            endpos = DepthTrace1.StartPos - Direction,
            filter = Trc.Entity,
            mask = MASK_SOLID_BRUSHONLY,
            output = TestDepth
        })
        
        if DepthTrace1.HitPos == TestDepth.HitPos or TestDepth.Fraction == 1 then
            util.TraceLine({
                start = Trc.HitPos + (Direction * Depth),
                endpos = Trc.HitPos,
                filter = Trc.Entity,
                mask = MASK_SOLID_BRUSHONLY,
                output = TestDepth
            })

            Dist = ((1 - TestDepth.Fraction) * Depth)
        else
            Dist = (Trc.HitPos:Distance(TestDepth.HitPos))
        end
    elseif IsValid(Trc.Entity) then
        util.TraceLine({
            start = Trc.HitPos + (Trc.Normal * Depth),
            endpos = Trc.HitPos,
            filter = Trc.Entity,
            whitelist = true,
            ignoreworld = true,
            --mask = MASK_SHOT,
            output = TestDepth
        })
        
        Dist = ((1 - TestDepth.Fraction) * Depth)
    end

    DistanceTravelled = DistanceTravelled + Dist
    if DistanceTravelled > TrcLength then 
        --return 0, 0 
    end


    TestDepth.Fraction = math.Round(TestDepth.Fraction, 4) -- floating point errors with the if statement below without it
    if TestDepth.Hit and TestDepth.Fraction ~= 1 and TestDepth.Fraction ~= 0 and not PointContents(TestDepth.HitPos, CONTENTS_SOLID) then

        
        if CLIENT then
            self:DoImpactEffect(TestDepth)
        end
        
        local Dist = Trc.HitPos:Distance(TestDepth.HitPos)
        local FractionLeft = 1 - (DistanceTravelled / TrcLength)
        util.TraceLine({
            start = TestDepth.HitPos + (Direction * 0.1),
            endpos = TestDepth.HitPos + (Direction * TrcLength * FractionLeft),
            filter = Trc.Entity,
            mask = MASK_SHOT,
            output = Trc
        })

        return FractionLeft, Dist
    end
    
    return 0, 0
end

function PROJECTILE:Penetrate()
    if not self.MoveTrace.Hit then return false end
    if self.MoveTrace.HitSky then return false end
    if self.MoveTrace.Fraction == 0 then return false end
    if not self:IsLethal() then return false end

    local MaterialInfo = Get(MaterialInfo, self.MoveTrace.MatType)
    --if self.CoreHardness < MaterialInfo.Hardness then return false end

    local HardnessSpeedPenalty = math.max(1, (MaterialInfo.Hardness - self.CoreHardness) * 2) 

    local Trace = self.MoveTrace

    local Vel = self.Velocity:Length()
    local Depth = math.min(Vel, Vel * self:GetUpdateRate() * MaterialInfo.PenetrationCoef * self.PenetrationMultiplier / HardnessSpeedPenalty)


    local RayLength = Trace.StartPos:Distance(Trace.HitPos) / Trace.Fraction
    local Direction = Trace.Normal
    local MaxSteps = 32
    local TotalPenetrationDistance = 0
    local NumPenetration = 0

    for i=1, MaxSteps do
        if Trace.Hit then
            self:FireBullet(Trace)
        end

        local FracLeft, PenetrationDistance = self:PenetrateRayStep(Trace, RayLength, Direction, Depth)
        RayLength = RayLength * FracLeft
        TotalPenetrationDistance = TotalPenetrationDistance + PenetrationDistance

        if i == 1 and RayLength == 0 then 
            Trace.Hit = true
            break
        end

        if RayLength == 0 or TotalPenetrationDistance >= Depth then 
            Trace.Hit = false
            break 
        end

        local Coef = (Depth - PenetrationDistance) / Depth
        self.Velocity = self.Velocity * Coef
        self.Position = Trace.StartPos + Trace.Normal

        NumPenetration = i

        if not Trace.Hit then
            Trace.Hit = false
            break
        end
    end

    return NumPenetration > 0
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


    local EFF = math.max(0, .5 * p * u^2 * Cd * A)
    local Fd = -self.Forward * .5 * p * u^2 * Cd * A

    --self.Velocity = self.Velocity + Fd
    self:ApplyForce(Fd * UpdateRate)


    self.TimeAtLastSimulation = SysTime()
    self.TickLifetime = self.TickLifetime + 1
 
    if self.Velocity:LengthSqr() < self.MinimumSpeed ^ 2 then
        self:Delete()
        return
    end

    if not self.Virtual and PointContents(self.Position, CONTENTS_SOLID) then
        self:Delete()
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
    PROJECTILE.BaseClass.OnSimulate(self)

    self:Crack()

    if self:Bounce() then return end
    if self:Penetrate() then return end
end

local TracerMaterial = Material("bulletphysics/tracer") --Material("effects/brightglow_y")
local GlowMaterial = Material("bulletphysics/glow")
--local Tracer = Material("effects/tracer_middle2")
local ColorWhite = Color(255, 255, 255)
local ColorWhite2 = Color(255, 255, 255, 128)

--local TracerColor = Color(255, 240, 220)

local ColCache = {}
local function ColorCache(r, g, b, a)
    local Index = "" .. r .. g .. b .. a
    local ColC = ColCache[Index]
    if not ColC then
        local Col = Color(r, g, b, a)
        ColCache[Index] = Col
        return Col
    end
    return ColC
end

local Radius = 6
function PROJECTILE:Render()
    --if not self.InterpolatedPosition:ToScreen().visible then return true end
    local TracerColor = self.TracerColor
    local GlowColor = self.GlowColor

    local Speed = self.Velocity:Length() * self:GetUpdateRate()

    if self.TickLifetime > 2 and not self.BouncedThisTick then
        local PixelDiameter = render.ComputePixelDiameterOfSphere(self.Position, Radius)

        local EyePosition = EyePos()
        local BulletPosition = self.InterpolatedPosition
        local BulletForward = self.Forward
        local DirectionToBullet = (BulletPosition - EyePosition):GetNormalized()

        local DotToBullet = math.abs(BulletForward:Dot(DirectionToBullet))

        local Scalar = 1 + (1 / (PixelDiameter * 0.3)) * 0.5
        local Radius = Radius * Scalar


        local Offset = (self.Position - self.LastPosition) * 0.4
        local Start, End = BulletPosition - Offset, BulletPosition + Offset

        local Offset = (self.Position - self.LastPosition) * 0.8
        local Start, End = BulletPosition - Offset, BulletPosition


        if self.Deleting then
            End = self.Position
        end

        render.SetMaterial(GlowMaterial)
        render.DrawBeam(Start, End, Radius * 5, 0.4, 0.6, TracerColor)
        

        render.SetMaterial(TracerMaterial)
        render.DrawBeam(Start, End, Radius, 0.2, 0.8, ColorWhite2)

        local Threshold = 0.95
        if DotToBullet > Threshold then

            local Alpha = math.Clamp(math.Remap(DotToBullet, Threshold, 1, 0, 1), 0, 1)

            local Radius = Radius * Alpha

            render.SetMaterial(GlowMaterial)
            render.DrawSprite(BulletPosition, Radius * 1.5, Radius * 1.5, TracerColor)

            render.SetMaterial(TracerMaterial)
            render.DrawSprite(BulletPosition, Radius, Radius, ColorWhite2)
        end
        

        local Intensity = math.ease.OutBounce(1 - math.min(1, self:GetLifetime() / 8)) ^ 10
        local Size = Intensity * Scalar * 1

        render.SetMaterial(GlowMaterial)
        render.DrawSprite(BulletPosition, 256 * Size, 256 * Size, GlowColor)
        render.DrawSprite(BulletPosition, 64 * Size, 64 * Size, GlowColor)
        render.DrawSprite(BulletPosition, 32 * Size, 32 * Size, GlowColor)

        if not self.Virtual then
            local Light = DynamicLight(10000000 + self.Index)
            Light.pos = BulletPosition
            Light.r = TracerColor.r
            Light.g = TracerColor.g
            Light.b = TracerColor.b
            Light.brightness = -4
            Light.decay = 1000
            Light.size = 512
            Light.dietime = CurTime() + 0.05
        end
    end

    return false
end

return PROJECTILE
