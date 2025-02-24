AddCSLuaFile()

local PROJECTILE = {}
PROJECTILE.__index = PROJECTILE
PROJECTILE.Base = "default_bullet"
PROJECTILE.Name = "default_tracer"

PROJECTILE.TracerColor = Color(255, 240, 180)


function PROJECTILE:Initialize()
    PROJECTILE.BaseClass.Initialize(self)
    self.GlowColor = Color(self.TracerColor.r, self.TracerColor.g, self.TracerColor.b, 1)

    if CLIENT then
        self.PixVis = util.GetPixelVisibleHandle()
    end
end

local TracerMaterial = Material("bulletphysics/tracer") --Material("effects/brightglow_y")
local GlowMaterial = Material("bulletphysics/glow")

local ColorWhite = Color(255, 255, 255)
local ColorWhite2 = Color(255, 255, 255, 128)

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