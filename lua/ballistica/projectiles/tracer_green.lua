AddCSLuaFile()

local PROJECTILE = {}
PROJECTILE.__index = PROJECTILE
PROJECTILE.Base = "default_tracer"
PROJECTILE.Name = "tracer_green"

PROJECTILE.TracerColor = Color(0, 255, 0)

return PROJECTILE