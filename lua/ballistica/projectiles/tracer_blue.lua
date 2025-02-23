AddCSLuaFile()

local PROJECTILE = {}
PROJECTILE.__index = PROJECTILE
PROJECTILE.Base = "default_bullet"
PROJECTILE.Name = "tracer_blue"

PROJECTILE.TracerColor = Color(0, 0, 255)

return PROJECTILE