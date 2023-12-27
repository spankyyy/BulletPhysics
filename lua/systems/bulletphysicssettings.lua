--local DefaultSettings = {
--    Projectiles = {
--        DefaultSpeed = 20000,
--        Gravity = 1000,
--        EnableSounds = true,
--        ShouldBounce = true,
--    },
--    DetouredWeapons = {
--        weapon_pistol = true,
--        weapon_357 = true,
--        weapon_smg1 = true,
--        weapon_ar2 = true,
--        weapon_shotgun = true
--    }
--}

// will add detoured weapons next
local DetouredWeaponBlacklist = {
    gmod_tool = true,
    gmod_camera = true,
    none = true
}

local ConvarCache = {}
local function GetConVarCached(ConvarName)
    if ConvarCache[ConvarName] == nil then
        local ConVar = GetConVar(ConvarName)
        ConvarCache[ConvarName] = ConVar
    end

    return ConvarCache[ConvarName]
end

if CLIENT then
    function BulletPhysicsGetConvars()
        local Convars = {}
        Convars.Speed = GetConVarCached("bulletphysics_defaultspeed")
        Convars.Gravity = GetConVarCached("bulletphysics_gravity")
        Convars.EnableSounds = GetConVarCached("bulletphysics_enablesounds")
        Convars.ShouldBounce = GetConVarCached("bulletphysics_enablebounce")
        return Convars
    end
end

if SERVER then

    -- create convars if they dont exist
    local name = "bulletphysics_defaultspeed"
    if not ConVarExists(name) then
        CreateConVar(name, 200000, FCVAR_ARCHIVE + FCVAR_REPLICATED, "Default speed of projectiles", 0, 1000000)
        print("Created new convar: " .. name)
    end

    local name = "bulletphysics_gravity"
    if not ConVarExists(name) then
        CreateConVar(name, 1000, FCVAR_ARCHIVE + FCVAR_REPLICATED, "Default gravity of projectiles", 0, 1000000)
        print("Created new convar: " .. name)
    end

    local name = "bulletphysics_enablesounds"
    if not ConVarExists(name) then
        CreateConVar(name, 1, FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable sounds for projectiles", 0, 1)
        print("Created new convar: " .. name)
    end

    local name = "bulletphysics_enablebounce"
    if not ConVarExists(name) then
        CreateConVar(name, 1, FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable ricochet for projectiles", 0, 1)
        print("Created new convar: " .. name)
    end

    local name = "bulletphysics_enablepenetration"
    if not ConVarExists(name) then
        CreateConVar(name, 1, FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable penetration for projectiles", 0, 1)
        print("Created new convar: " .. name)
    end

    function BulletPhysicsGetConvars()
        local Convars = {}
        Convars.Speed = GetConVarCached("bulletphysics_defaultspeed")
        Convars.Gravity = GetConVarCached("bulletphysics_gravity")
        Convars.EnableSounds = GetConVarCached("bulletphysics_enablesounds")
        Convars.ShouldBounce = GetConVarCached("bulletphysics_enablebounce")
        return Convars
    end
end