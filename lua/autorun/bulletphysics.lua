AddCSLuaFile()

include("systems/c_hitboxsystem.lua")
include("systems/c_lagcompensationmanager.lua")
include("systems/c_projectilemanager.lua")
include("systems/c_projectilesystem.lua")

include("systems/bulletphysicssettings.lua")

// Utility modules
local net = include("utility/extranet.lua")

local BulletPhysics = {}
_G.BulletPhysics = BulletPhysics

-- Cached functions
local player_GetCount = player.GetCount
local player_GetAll = player.GetAll

local function Fallback(tbl, index, fallback)
    if not tbl then return end
    if not index then return end

    if tbl[index] == nil then
        tbl[index] = fallback
    end
    return tbl[index]
end

-- Hook name
local HookIndentifier = "BPhys_"
BulletPhysics.HookIdentifier = HookIndentifier

-- Initialize the systems
local BulletPhysicsProjectileSystem = C_ProjectileSystem:New()
BulletPhysics.ProjectileSystem = BulletPhysicsProjectileSystem


// Settings

/////////////////////////////////////////////////////////////////////////////////////////////////////

-- Network bullets created by global managers
local function OnCreateProjectile(self, BulletInfo)
    local BulletInfo = BulletInfo

    Fallback(BulletInfo, "Settings", {})

    local ConvarSettings = BulletPhysicsGetConvars()
    Fallback(BulletInfo.Settings, "Speed", ConvarSettings.Speed:GetInt())
    Fallback(BulletInfo.Settings, "Gravity", ConvarSettings.Gravity:GetInt())
    Fallback(BulletInfo.Settings, "EnableSounds", ConvarSettings.EnableSounds:GetBool())
    Fallback(BulletInfo.Settings, "ShouldBounce", ConvarSettings.ShouldBounce:GetBool())

    -- Send messages to players other than attacker
    net.Start(HookIndentifier .. "NetworkBullets", true)
        net.WriteEntity(BulletInfo.Attacker)
        net.WriteFloat(BulletInfo.Settings.Speed)
        net.WriteFloat(BulletInfo.Settings.Gravity)
        net.WriteBool(BulletInfo.Settings.ShouldBounce)
        net.WriteBool(BulletInfo.Settings.EnableSounds)
        net.WriteVectorFloat(BulletInfo.Dir)
        net.WriteVectorFloat(BulletInfo.Src)
    net.OmitBroad(BulletInfo.Attacker)
end

-- Create a manager for the player
local function AssignManager(Player)
    -- Returns if the player already has a manager
    local PlayerManager = Player:GetProjectileManager()
    if PlayerManager then 
        BulletPhysicsProjectileSystem:RemoveManager(PlayerManager)
        Player:RemoveProjectileManager()
    end
    local NewManager = BulletPhysicsProjectileSystem:NewManager()

    -- Make the manager predicted
    NewManager:EnablePrediction()

    NewManager:AttachToPlayer(Player)
    -- Network bullets to other players
    if SERVER then
        NewManager.OnCreateProjectile = OnCreateProjectile
    end
end


-- Only available on server
if SERVER then
    -- Network string for sending bullets to clients
    util.AddNetworkString(HookIndentifier .. "NetworkBullets")
    util.AddNetworkString(HookIndentifier .. "ClientReady")

    net.Receive(HookIndentifier .. "ClientReady", function(_, Player)
        AssignManager(Player)
    end)

    -- Allow for lua refresh
    local PlayerCount = player_GetCount()
    local Players = player_GetAll()

    for i = 1, PlayerCount do
        AssignManager(Players[i])
    end

    -- Create the server manager
    BulletPhysicsProjectileSystem:CreateGlobalManager()
    BulletPhysicsProjectileSystem:GetGlobalManager().OnCreateProjectile = OnCreateProjectile



    function weapons.GetListByCategory()
        local Categories = {}

        local WeaponList = weapons.GetList()

        for k, Weapon in next, WeaponList do
            if Weapon.Category and Weapon.Spawnable then
                local Category = Fallback(Categories, Weapon.Category, {})

                Category[#Category+1] = Weapon
            end
        end
        return Categories
    end

    --PrintTable(GetWeaponsByCategory())

    for k,v in pairs(weapons.GetListByCategory()) do
        --print(#v, k)
        print(string.format("(%G) - %s", #v, k))
    end
end

if CLIENT then
    hook.Add("InitPostEntity", HookIndentifier .. "LocalPlayerSpawned", function()
        AssignManager(LocalPlayer())
        _G.BulletPhysicsClientInitialized = true

        net.Start(HookIndentifier .. "ClientReady")
        net.SendToServer()
    end)

    -- Allow for lua refresh
    if _G.BulletPhysicsClientInitialized then
        AssignManager(LocalPlayer())
    end

    -- Create the client manager
    BulletPhysicsProjectileSystem:CreateGlobalManager()

    -- Receive bullets from sources other than localplayer
    net.Receive(HookIndentifier .. "NetworkBullets", function()
        local BulletInfo = {}
        BulletInfo.Settings = {}

        BulletInfo.Attacker = net.ReadEntity()
        BulletInfo.Settings.Speed = net.ReadFloat()
        BulletInfo.Settings.Gravity = net.ReadFloat()
        BulletInfo.Settings.ShouldBounce = net.ReadBool()
        BulletInfo.Settings.EnableSounds = net.ReadBool()

        BulletInfo.Dir = net.ReadVectorFloat()
        BulletInfo.Src = net.ReadVectorFloat()

        local Manager = BulletPhysicsProjectileSystem:GetGlobalManager()
        local Projectile = Manager:CreateProjectile(BulletInfo)
    end)
end


// Shared

-- Run predicted managers
hook.Add("SetupMove", HookIndentifier .. "PredictedManagerLogic", function(Player, CMoveData, CUserCmd)
    -- Run manager for the player
    local Manager = Player:GetProjectileManager()
    if Manager then
        Manager:OnSetupMove(Player, CMoveData, CUserCmd)
    end
end)

-- Run unpredicted managers
hook.Add("Tick", HookIndentifier .. "UnpredictedManagerLogic", function()
    -- Run managers for every projectile system
    for _, Manager in ipairs(BulletPhysicsProjectileSystem:GetManagers()) do
        -- Run the manager
        Manager:OnSetupMoveUnpredicted()
    end

    local GlobalManager = BulletPhysicsProjectileSystem:GetGlobalManager()
    GlobalManager:OnSetupMoveUnpredicted()
end)


-- Detours the FireBullets function
EntityMeta = FindMetaTable("Entity")
EntityMeta._FireBullets = EntityMeta._FireBullets or EntityMeta.FireBullets
function EntityMeta:FireBullets(BulletInfo)
    local ConvarSettings = BulletPhysicsGetConvars()
    -- Master killswitch
    if not ConvarSettings.Enabled:GetBool() then
        self:_FireBullets(BulletInfo)
        return
    end

    -- Localize BulletInfo to prevent editing of the table outside the function
    local BulletInfo = table.Copy(BulletInfo)

    -- Sets the bullet's attacker
    BulletInfo.Attacker = self

    -- Remove callback function
    BulletInfo.Callback = nil

    -- Track which bullets are which
    BulletInfo.TracerName = "Projectile"
    -- Get the muzzle position
    //if CLIENT and self:IsPlayer() then
    //    local ViewModel = self:GetViewModel()
    //    local Muzzle = ViewModel:LookupAttachment("muzzle")
    //    if Muzzle > 0 then
    //        local Muzzle = ViewModel:GetAttachment(Muzzle)
    //        if Muzzle then
    //            print(Muzzle.Pos, Muzzle.Ang)
    //            debugoverlay.Sphere(Muzzle.Pos, 8, 1, Color(255, 255, 255, 0))
    //        end
    //    end
    //    BulletInfo.MuzzlePosition = nil
    //end

    -- Create the table if it doesnt exist
    Fallback(BulletInfo, "Settings", {})

    Fallback(BulletInfo.Settings, "Speed", ConvarSettings.Speed:GetInt())
    Fallback(BulletInfo.Settings, "Gravity", ConvarSettings.Gravity:GetInt())
    Fallback(BulletInfo.Settings, "EnableSounds", ConvarSettings.EnableSounds:GetBool())
    Fallback(BulletInfo.Settings, "ShouldBounce", ConvarSettings.ShouldBounce:GetBool())
    
    -- Shoot many bullets
    local Num = BulletInfo.Num or 1
    for NumBullets = 1, Num do
        -- Save bullet.dir for later so we can revert back (Spread modifies the direction)
        local Dir = BulletInfo.Dir
        
        if BulletInfo.Spread then
            ProjectileInfo:CalculateSpread(BulletInfo, engine.TickCount(), NumBullets)
        end

        if self:IsPlayer() then
            -- Get the player's assigned manager
            local Manager = self:GetProjectileManager()

            -- Create the projectile
            Manager:CreateProjectile(BulletInfo)
        elseif SERVER then
            -- Gets the serverside manager
            local Manager = BulletPhysicsProjectileSystem:GetGlobalManager()

            -- Create the projectile
            Manager:CreateProjectile(BulletInfo)
        end

        -- Revert back
        BulletInfo.Dir = Dir
    end
end

-- Override bullets from engine weapons
hook.Add("PostEntityFireBullets", HookIndentifier .. "FireBullets", function(Entity, BulletInfo)
    local ConvarSettings = BulletPhysicsGetConvars()

    if not ConvarSettings.Enabled:GetBool() then
        return true
    end

    -- Dont override our bullets
    if BulletInfo.TracerName == "Projectile" then return true end

    local BulletInfo = BulletInfo

    local Trace = BulletInfo.Trace
    BulletInfo.Dir = (Trace.HitPos - Trace.StartPos):GetNormalized()
    BulletInfo.Src = Trace.StartPos
    BulletInfo.Attacker = Entity

    Entity:FireBullets(BulletInfo)

    -- Suppress the bullet
    return false
end)


/////////////////////////////////////////////////////////////////////////////////////////////////////

-- Rendering

if CLIENT then
    hook.Add("Think", HookIndentifier .. "ProjectileInterpolation", function()

        -- Interpolate local bullets
        local Manager = LocalPlayer():GetProjectileManager()
        if Manager then
            Manager:InterpolateProjectilePositions()
        end

        -- Interpolate global bullets
        local Manager = BulletPhysicsProjectileSystem:GetGlobalManager()
        if Manager then
            Manager:InterpolateProjectilePositions()
        end
    end)

    hook.Add("Think", HookIndentifier .. "BulletFlyby", function()
        -- Interpolate local bullets
        local Manager = LocalPlayer():GetProjectileManager()
        if Manager then
            Manager:CrackProjectiles()
        end

        -- Interpolate global bullets
        local Manager = BulletPhysicsProjectileSystem:GetGlobalManager()
        if Manager then
            Manager:CrackProjectiles()
        end
    end)

    hook.Add("PostDrawTranslucentRenderables", HookIndentifier .. "ProjectileRender", function()
        -- Render localplayer's bullets
        local Manager = LocalPlayer():GetProjectileManager()
        if Manager then
            Manager:RenderProjectiles()
        end

        -- Render global bullets
        local Manager = BulletPhysicsProjectileSystem:GetGlobalManager()
        if Manager then
            Manager:RenderProjectiles()
        end
    end)
end