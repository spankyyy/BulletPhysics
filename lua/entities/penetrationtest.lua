AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Test Penetration"
ENT.Category = "Bullet Physics"
ENT.Spawnable = true
ENT.AdminOnly = true

DEFINE_BASECLASS(ENT.Base)

local SimOnServer = true

local function PointContents(Pos, Content)
    return bit.band(util.PointContents(Pos), Content) == Content
end

local Life = 0
local EnableZ = true
local function PenetrateRayStep(Trc, TrcLength, Direction, Depth)
    if not Trc.Hit then return 0 end
    local DistanceTravelled = TrcLength * Trc.Fraction
    
    local DepthTrace1 = {}
    local TestDepth = {}
    local Dist = 0
    if Trc.HitWorld then
        util.TraceLine({
            start = Trc.HitPos + (Direction * 1),
            --start = Trc.HitPos - (Trc.HitNormal * 1),
            endpos = Trc.HitPos + (Direction * Depth),
            filter = Trc.Entity,
            mask = MASK_SOLID_BRUSHONLY + MASK_SHOT,
            output = DepthTrace1
        })

        util.TraceLine({
            start = DepthTrace1.HitPos,
            endpos = DepthTrace1.StartPos - Direction,
            filter = Trc.Entity,
            mask = MASK_SOLID_BRUSHONLY + MASK_SHOT,
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
    else
        util.TraceLine({
            start = Trc.HitPos + (Direction * Depth),
            endpos = Trc.HitPos,
            filter = Trc.Entity,
            whitelist = true,
            ignoreworld = true,
            mask = MASK_SHOT,
            output = TestDepth
        })
        Dist = ((1 - TestDepth.Fraction) * Depth)
    end

    DistanceTravelled = DistanceTravelled + Dist
    if DistanceTravelled > TrcLength then return 0 end


    if TestDepth.Hit and TestDepth.Fraction ~= 1 and TestDepth.Fraction ~= 0 and not PointContents(TestDepth.HitPos, CONTENTS_SOLID) then

        debugoverlay.Line(Trc.HitPos, TestDepth.HitPos, Life, Color(0, 0, 255), EnableZ)
        debugoverlay.Sphere(TestDepth.HitPos, 0.5, Life, Color(0, 0, 255, 0), EnableZ)
        debugoverlay.Sphere(Trc.HitPos, 0.5, Life, Color(0, 0, 255, 0), EnableZ)
    
        --debugoverlay.Sphere(TestDepth.HitPos, 0.75, Life, Color(255, 0, 128, 0), EnableZ)
        --debugoverlay.Sphere(TestDepth.StartPos, 0.75, Life, Color(128, 0, 255, 0), EnableZ)

        local FractionLeft = 1 - (DistanceTravelled / TrcLength)
        util.TraceLine({
            start = TestDepth.HitPos + (Direction * 0.1),
            endpos = TestDepth.HitPos + (Direction * TrcLength * FractionLeft),
            mask = MASK_SHOT,
            output = Trc
        })
        
        debugoverlay.Line(Trc.StartPos, Trc.HitPos, Life, Color(0, 255, 0), EnableZ)
        return FractionLeft
    end
    return 0
end

-- Returns: boolean Penetrated
function PenetrateRay(Trace, Depth, MaxSteps)
    local RayLength = Trace.StartPos:Distance(Trace.HitPos) / Trace.Fraction
    local Direction = Trace.Normal

    for i=1, MaxSteps do
        local Str = IsValid(Trace.Entity) and "DoDamageHere - " .. tostring(Trace.Entity) or "DoDamageHere"
        --debugoverlay.Text(Trace.HitPos + Vector(0, 0, 4), Str, Life, false)
        --debugoverlay.Sphere(Trace.HitPos, 1, Life, Color(255, 255, 255, 0), EnableZ)

        local FracLeft = PenetrateRayStep(Trace, RayLength, Direction, Depth)
        RayLength = RayLength * FracLeft

        if i == 1 and RayLength == 0 then 
            return false
        end
        if RayLength == 0 then break end
    end
    return true
end

local resx = 1
local resy = 1

local fovx = 1
local fovy = 15

if SERVER then
    function ENT:Initialize()
        BaseClass.Initialize(self)
        self:SetModel("models/maxofs2d/cube_tool.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:GetPhysicsObject():Wake()
        self:SetUseType(SIMPLE_USE)
    end

    function ENT:Think()
        if not SimOnServer then return end
        self:NextThink(CurTime())
        local StartPos = self:GetPos() - self:GetForward() * 0
        local Direction = -self:GetForward()
        
        local Depth = 64
        local Speed = 390
        local MaxStep = 32

        local resx = resx - 1
        local resy = resy - 1

        for x=0, resx do
            x = -fovx + (x / resx * fovx * 2)
            if resx == 0 then x = 0 end
            
            for y=0, resy do
                y = -fovy + (y / resy * fovy * 2)
                if resy == 0 then y = 0 end

                local Direction = self:LocalToWorldAngles(Angle(y, 180 + x, 0)):Forward()

                local Trace = {}
                util.TraceLine({
                    start = StartPos,
                    endpos = StartPos + (Direction * Speed),
                    filter = self,
                    output = Trace
                })


                debugoverlay.Line(Trace.StartPos, Trace.HitPos, Life, Color(255, 0, 0), EnableZ)
                debugoverlay.Text(self:GetPos() + self:GetUp() * 9, "Max Pen Dist: " .. Depth, Life, false)
                debugoverlay.Text(self:GetPos() - self:GetUp() * 9, "Max Steps: " .. MaxStep, Life, false)

                PenetrateRay(Trace, Depth, MaxStep)

                do  
                    --debugoverlay.Sphere(Trace.StartPos, 2.5, Life, Color(255, 128, 0, 0), EnableZ)
                    debugoverlay.Sphere(Trace.HitPos, 1, Life, Color(255, 255, 0, 0), EnableZ)

                    local Average = (Trace.StartPos + Trace.HitPos) * .5
                    --debugoverlay.Text(Average, "Final Ray", Life, false)
                    --debugoverlay.Text(Trace.StartPos, "Start", Life, false)
                    --debugoverlay.Text(Trace.HitPos, "End", Life, false)
                end
            end
        end

        return true
    end
end

if CLIENT then
    function ENT:Initialize()

    end

    function ENT:Think()
        if SimOnServer then return end
        self:NextThink(CurTime())
        local StartPos = self:GetPos() - self:GetForward() * 0
        local Direction = -self:GetForward()
        
        local Depth = 64
        local Speed = 1024
        local MaxStep = 32

        local resx = resx - 1
        local resy = resy - 1

        for x=0, resx do
            x = -fovx + (x / resx * fovx * 2)
            if resx == 0 then x = 0 end
            
            for y=0, resy do
                y = -fovy + (y / resy * fovy * 2)
                if resy == 0 then y = 0 end

                local Direction = self:LocalToWorldAngles(Angle(y, 180 + x, 0)):Forward()

                local Trace = {}
                util.TraceLine({
                    start = StartPos,
                    endpos = StartPos + (Direction * Speed),
                    filter = self,
                    output = Trace
                })


                debugoverlay.Line(Trace.StartPos, Trace.HitPos, Life, Color(255, 0, 0), EnableZ)
                debugoverlay.Text(self:GetPos() + self:GetUp() * 9, "Max Pen Dist: " .. Depth, Life, false)
                debugoverlay.Text(self:GetPos() - self:GetUp() * 9, "Max Steps: " .. MaxStep, Life, false)

                PenetrateRay(Trace, Depth, MaxStep)

                do  
                    --debugoverlay.Sphere(Trace.StartPos, 2.5, Life, Color(255, 128, 0, 0), EnableZ)
                    debugoverlay.Sphere(Trace.HitPos, 1, Life, Color(255, 255, 0, 0), EnableZ)

                    local Average = (Trace.StartPos + Trace.HitPos) * .5
                    --debugoverlay.Text(Average, "Final Ray", Life, false)
                    --debugoverlay.Text(Trace.StartPos, "Start", Life, false)
                    --debugoverlay.Text(Trace.HitPos, "End", Life, false)
                end
            end
        end

        return true
    end

    function ENT:Draw()
        render.SuppressEngineLighting(true)
        self:DrawModel()
        render.SuppressEngineLighting(false)
    end
end
