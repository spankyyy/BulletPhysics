AddCSLuaFile()

local PROJECTILE = {}
PROJECTILE.__index = PROJECTILE
PROJECTILE.Base = "default_bullet"
PROJECTILE.Name = "tracer_red"

PROJECTILE.TracerColor = Color(255, 0, 0)

return PROJECTILE