AddCSLuaFile()

include("ballistica/ballistica.lua")

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

function CalculateSpread(BulletInfo, Seed, Extra)
    if not BulletInfo.Spread then return end
    BulletInfo.Dir = Spread(BulletInfo.Dir, BulletInfo.Spread[1] * 90, Seed, Extra)
end

local _AmmoTypeCache = {}
function GetAmmoTypeDamage(AmmoID)
    -- Attempt to return a cached value first.
    if _AmmoTypeCache[AmmoID] then return _AmmoTypeCache[AmmoID] end
    -- Set the cached variable for appropriate ammo type.
    _AmmoTypeCache[AmmoID] = game.GetAmmoPlayerDamage(AmmoID)

    return _AmmoTypeCache[AmmoID]
end

local ConvarCache = {}
local function GetConVarCached(ConvarName)
    if ConvarCache[ConvarName] == nil then
        local ConVar = GetConVar(ConvarName)
        ConvarCache[ConvarName] = ConVar
    end

    return ConvarCache[ConvarName]
end


EntityMeta = FindMetaTable("Entity")
EntityMeta._FireBullets = EntityMeta._FireBullets or EntityMeta.FireBullets

function EntityMeta:CreateProjectile(BulletInfo, ClassName)
    BulletInfo.Attacker = BulletInfo.Attacker or self
    return Ballistica:CreateProjectile(BulletInfo, ClassName)
end

local function _FireBullets(self, BulletInfo)
    local Convars = BulletPhysicsGetConvars()
    if not IsFirstTimePredicted() and not game.SinglePlayer() then return end
    if BulletInfo == nil then return end

    -- Localize BulletInfo to prevent editing of the table outside the function
    --local BulletInfo = table.Copy(BulletInfo)
    
    -- Sets the bullet's attacker
    BulletInfo.Attacker = self

    local Damage, AmmoType = BulletInfo.Damage, BulletInfo.AmmoType
    if Damage == 0 and (AmmoType ~= "" and AmmoType ~= nil) then
        BulletInfo.Damage = GetAmmoTypeDamage(game.GetAmmoID(AmmoType))
    elseif Damage == 0 and (AmmoType == nil or AmmoType == "") then
        --BulletInfo.Damage = 10
    end

    -- Shoot many bullets
    local Num = BulletInfo.Num or 1
    for NumBullets = 1, Num do
        -- Save bullet.dir for later so we can revert back (Spread modifies the direction)
        local Dir = BulletInfo.Dir
        
        if BulletInfo.Spread then
            CalculateSpread(BulletInfo, engine.TickCount() * self:EntIndex(), NumBullets)
        end
        
        local Projectile = self:CreateProjectile(BulletInfo, BulletInfo.Class or Convars.ProjectileName:GetString()  or "default_bullet")
        Projectile.Damage = BulletInfo.Damage or 0

        -- Revert back
        BulletInfo.Dir = Dir
    end
end

function EntityMeta:FireBullets(BulletInfo)
    local Convars = BulletPhysicsGetConvars()
    if not Convars.Enabled:GetBool() then 
        self:_FireBullets(BulletInfo)
        return 
    end

    _FireBullets(self, BulletInfo)
end

-- Override bullets from engine weapons
hook.Add("PostEntityFireBullets", "BulletPhysics_FireBullets", function(Entity, BulletInfo)
    local Convars = BulletPhysicsGetConvars()

    if not Convars.Enabled:GetBool() then return end
    if not IsFirstTimePredicted() then return end

    -- Dont override our bullets (Shouldnt need this anymore but im keeping it just in case)
    if BulletInfo.TracerName == "Projectile" then return true end

    local BulletInfo = BulletInfo -- ?

    local Trace = BulletInfo.Trace
    BulletInfo.Dir = (Trace.HitPos - Trace.StartPos):GetNormalized()
    BulletInfo.Src = Trace.StartPos
    BulletInfo.Attacker = Entity
    
    Entity:FireBullets(BulletInfo)
    --_FireBullets(Entity, BulletInfo)
    -- Suppress the bullet
    return false
end)
