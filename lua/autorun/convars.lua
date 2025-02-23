AddCSLuaFile()

local ConvarCache = {}
local function GetConVarCached(ConvarName)
    if ConvarCache[ConvarName] == nil then
        local ConVar = GetConVar(ConvarName)
        ConvarCache[ConvarName] = ConVar
    end

    return ConvarCache[ConvarName]
end

local convars = {
    {"bulletphysics_enabled", 1, "Master killswitch", 0, 1},
    {"bulletphysics_projectilename", "default_bullet", "Projectile name"}
}

if SERVER then
    util.AddNetworkString("BulletPhysics_NetworkConvars")
    
    -- Create convars
    for k, convar in ipairs(convars) do
        if not ConVarExists(convar[1]) then
            CreateConVar(convar[1], convar[2], FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY, convar[3], convar[4], convar[5])
            print("Created new convar: " .. convar[1])
        end
    end


    -- Receive new/changed convars from superadmins
    net.Receive("BulletPhysics_NetworkConvars", function(len, ply)
        local name = net.ReadString()
        local val = net.ReadString()
        if ply:IsSuperAdmin() then
            local Convar = GetConVarCached(name)
            Convar:SetString(val)
        else
            print("BULLETPHYSICS - Player not superadmin, Ignoring")
        end
    end)
end

if CLIENT then
    for k, convar in ipairs(convars) do
        if not ConVarExists(convar[1]) then
            local Convar = CreateConVar(convar[1], convar[2], FCVAR_ARCHIVE, convar[3], convar[4], convar[5])
            cvars.AddChangeCallback(convar[1], function(name, old, new)
                if old == new then return end
                if not LocalPlayer():IsSuperAdmin() then
                    --Convar:SetString(old)
                    print("BULLETPHYSICS - You are not allowed to use this, Superadmin only.")
                else
                    -- Send the update to server (it checks if youre superadmin, no fooling around)
                    net.Start("BulletPhysics_NetworkConvars")
                        net.WriteString(name)
                        net.WriteString(new)
                    net.SendToServer()
                end
            end)

            print("Created new convar: " .. convar[1])
        end
    end
end


function BulletPhysicsGetConvars()
    local Convars = {}
    Convars.ProjectileName = GetConVarCached("bulletphysics_projectilename")
    Convars.Enabled = GetConVarCached("bulletphysics_enabled")
    return Convars
end