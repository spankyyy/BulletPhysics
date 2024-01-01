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


local HookIndentifier = "BPhys_"
if SERVER then
    util.AddNetworkString(HookIndentifier .. "NetworkConvars")
    
    for k, convar in ipairs(convars) do
        if not ConVarExists(convar[1]) then
            CreateConVar(convar[1], convar[2], FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY, convar[3], convar[4], convar[5])
            print("Created new convar: " .. convar[1])
        end
    end

    net.Receive(HookIndentifier .. "NetworkConvars", function(len, ply)
        local name = net.ReadString()
        local val = net.ReadString()
        if ply:IsSuperAdmin() then
            local Convar = GetConVarCached(name)
            Convar:SetString(val)
        else
            print("Player not superadmin, Ignoring")
        end
    end)

end

if CLIENT then
    for k, convar in ipairs(convars) do
        if not ConVarExists(convar[1]) then
            local Convar = CreateConVar(convar[1], convar[2], FCVAR_ARCHIVE, convar[3], convar[4], convar[5])
            cvars.AddChangeCallback(convar[1], function(name, old, new)
                if not LocalPlayer():IsSuperAdmin() then
                    Convar:SetString(old)
                    print("You are not allowed to use this, SUPERADMIN only")
                    return
                end

                net.Start(HookIndentifier .. "NetworkConvars")
                    net.WriteString(name)
                    net.WriteString(new)
                net.SendToServer()
            end)

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