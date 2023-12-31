AddCSLuaFile()
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
--local DetouredWeaponBlacklist = {
--    gmod_tool = true,
--    gmod_camera = true,
--    none = true
--}

local ConvarCache = {}
local function GetConVarCached(ConvarName)
    if ConvarCache[ConvarName] == nil then
        local ConVar = GetConVar(ConvarName)
        ConvarCache[ConvarName] = ConVar
    end

    return ConvarCache[ConvarName]
end
local convars = {
    {"bulletphysics_defaultspeed", 30000, "Default speed of projectiles", 0, 100000},
    {"bulletphysics_gravity", 1000, "Default gravity of projectiles", 0, 100000},
    {"bulletphysics_enablesounds", 1, "Enable sounds for projectiles", 0, 1},
    {"bulletphysics_enablebounce", 1, "Enable ricochet for projectiles", 0, 1},
    {"bulletphysics_enablepenetration", 1, "Enable penetration for projectiles", 0, 1},
    {"bulletphysics_enabled", 1, "Master killswitch", 0, 100000}
}

-- create convars if they dont exist
//local name = "bulletphysics_defaultspeed"
//if not ConVarExists(name) then
//    CreateConVar(name, 30000, FCVAR_ARCHIVE + FCVAR_REPLICATED, "Default speed of projectiles", 0, 1000000)
//    print("Created new convar: " .. name)
//end
//
//local name = "bulletphysics_gravity"
//if not ConVarExists(name) then
//    CreateConVar(name, 1000, FCVAR_ARCHIVE + FCVAR_REPLICATED, "Default gravity of projectiles", 0, 1000000)
//    print("Created new convar: " .. name)
//end
//
//local name = "bulletphysics_enablesounds"
//if not ConVarExists(name) then
//    CreateConVar(name, 1, FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable sounds for projectiles", 0, 1)
//    print("Created new convar: " .. name)
//end
//
//local name = "bulletphysics_enablebounce"
//if not ConVarExists(name) then
//    CreateConVar(name, 1, FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable ricochet for projectiles", 0, 1)
//    print("Created new convar: " .. name)
//end
//
//local name = "bulletphysics_enablepenetration"
//if not ConVarExists(name) then
//    CreateConVar(name, 1, FCVAR_ARCHIVE + FCVAR_REPLICATED, "Enable penetration for projectiles", 0, 1)
//    print("Created new convar: " .. name)
//end
//
//local name = "bulletphysics_enabled"
//if not ConVarExists(name) then
//    CreateConVar(name, 1, FCVAR_ARCHIVE + FCVAR_REPLICATED, "Master killswitch", 0, 1)
//    print("Created new convar: " .. name)
//end

if SERVER then
    for k, convar in ipairs(convars) do
        if not ConVarExists(convar[1]) then
            CreateConVar(convar[1], convar[2], FCVAR_ARCHIVE + FCVAR_REPLICATED, convar[3], convar[4], convar[5])
            print("Created new convar: " .. convar[1])
        end
    end
end

if CLIENT then
    for k, convar in ipairs(convars) do
        if not ConVarExists(convar[1]) then
            CreateConVar(convar[1], convar[2], FCVAR_ARCHIVE, convar[3], convar[4], convar[5])
            print("Created new convar: " .. convar[1])
        end
    end
end


function BulletPhysicsGetConvars()
    local Convars = {}
    Convars.Speed = GetConVarCached("bulletphysics_defaultspeed")
    Convars.Gravity = GetConVarCached("bulletphysics_gravity")
    Convars.EnableSounds = GetConVarCached("bulletphysics_enablesounds")
    Convars.ShouldBounce = GetConVarCached("bulletphysics_enablebounce")
    Convars.Enabled = GetConVarCached("bulletphysics_enabled")
    return Convars
end