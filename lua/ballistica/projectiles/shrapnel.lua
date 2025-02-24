AddCSLuaFile()

local PROJECTILE = {}
PROJECTILE.__index = PROJECTILE
PROJECTILE.Base = "default_bullet"
PROJECTILE.Name = "shrapnel"

PROJECTILE.PenetrationMultiplier = 0.1

PROJECTILE.CoreHardness = HARDNESS.SOFT -- lead
PROJECTILE.Diameter = 2 -- in mm
PROJECTILE.Weight = 0.001 -- in kg
PROJECTILE.DragCoefficient = 1.25 -- (unitless, it is derived from many other variables)

function PROJECTILE:Render()
end


local Green = Color(0, 255, 0, 255)
local Yellow = Color(255, 255, 0, 32)
local Red = Color(255, 0, 0, 255)
local Lifetime = 0
--function PROJECTILE:Render()
--    if self.Attacker:IsPlayer() and self.TickLifetime == 0 then return end
--    
--    render.SetColorMaterial()
--    render.DrawSphere(self:GetPos(), 6, 30, 30, Green)
--    render.DrawSphere(self:GetRealPos(), 12, 30, 30, Yellow)
--    render.DrawBeam(self:GetPos(), self:GetPos() + self.Forward * 32, 1, 0, 1, Red)
--end


return PROJECTILE