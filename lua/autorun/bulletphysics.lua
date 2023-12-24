AddCSLuaFile()

include("systems/c_hitboxsystem.lua")
include("systems/c_lagcompensationmanager.lua")
include("systems/c_projectilemanager.lua")
include("systems/c_projectilesystem.lua")
include("systems/settings.lua")

local BulletPhysics = {}
_G.BulletPhysics = BulletPhysics

-- Cached functions
local player_GetCount = player.GetCount
local player_GetAll = player.GetAll

-- Hook name
local HookIndentifier = "BPhys_"
BulletPhysics.HookIdentifier = HookIndentifier

-- Initialize the systems
local BulletPhysicsProjectileSystem = C_ProjectileSystem:New()
BulletPhysics.ProjectileSystem = BulletPhysicsProjectileSystem


// Settings
BulletPhysics.Settings = BulletPhysics.Settings or {}

local function NetworkSettingsToClients(Settings)
    timer.Simple(0, function()
        net.Start("NetworkBulletPhysicsSettings")
            net.WriteTable(Settings)
        net.Broadcast()
    end)
end

if SERVER then
    BulletPhysicsSettings:UpdateSettings()
    BulletPhysics.Settings = BulletPhysicsSettings:GetSettings()
    NetworkSettingsToClients(BulletPhysics.Settings)
else
    net.Receive("NetworkBulletPhysicsSettings", function()
        local Settings = net.ReadTable()

        BulletPhysics.Settings = Settings
        print("Bullet Physics: Updated Client settings")
    end)
end

/////////////////////////////////////////////////////////////////////////////////////////////////////

local function IsCurrentWeaponDetoured(Player)
    if Player:IsPlayer() then
        local CurrentWeapon = Player:GetActiveWeapon()
        if CurrentWeapon:IsValid() then
            return not BulletPhysics.Settings.DetouredWeapons[CurrentWeapon:GetClass()]
        end
    end
    return false
end

-- Network bullets created by global managers
local function OnCreateProjectile(self, BulletInfo)
    local BulletInfo = BulletInfo

    local Players = RecipientFilter(true)
    Players:AddAllPlayers()
    if BulletInfo.Attacker:IsPlayer() and not game.SinglePlayer() then
        Players:RemovePlayer(BulletInfo.Attacker)
    end

    -- Dont run if theres no players to send a message to
    if Players:GetCount() == 0 then return end
    -- Send messages to players other than attacker
    net.Start(HookIndentifier .. "NetworkBullets", true)
        net.WriteEntity(BulletInfo.Attacker)
        net.WriteFloat(BulletInfo.HullSize)
        net.WriteFloat(BulletInfo.Speed or 20000)
        net.WriteFloat(BulletInfo.Gravity or 1000)
        net.WriteFloat(BulletInfo.Dir[1])
        net.WriteFloat(BulletInfo.Dir[2])
        net.WriteFloat(BulletInfo.Dir[3])
        net.WriteFloat(BulletInfo.Src[1])
        net.WriteFloat(BulletInfo.Src[2])
        net.WriteFloat(BulletInfo.Src[3])
    net.Send(Players)
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
    -- Assign a manager to players that join the game
    hook.Add("PlayerInitialSpawn", HookIndentifier .. "PlayerSpawned", function(Player)
        AssignManager(Player)

        -- Network settings to new players
        NetworkSettingsToClients(BulletPhysics.Settings)
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
end

if CLIENT then
    hook.Add("InitPostEntity", HookIndentifier .. "LocalPlayerSpawned", function()
        AssignManager(LocalPlayer())
        _G.BulletPhysicsClientInitialized = true
    end)
    if _G.BulletPhysicsClientInitialized then
        AssignManager(LocalPlayer())
    end

    -- Create the client manager
    BulletPhysicsProjectileSystem:CreateGlobalManager()

    -- Receive bullets from sources other than localplayer
    net.Receive(HookIndentifier .. "NetworkBullets", function()
        local BulletInfo = {}

        BulletInfo.Attacker = net.ReadEntity()
        BulletInfo.HullSize = net.ReadFloat()
        local Speed = net.ReadFloat()
        local Gravity = net.ReadFloat()
        BulletInfo.Dir = Vector(net.ReadFloat(), net.ReadFloat(), net.ReadFloat())
        BulletInfo.Src = Vector(net.ReadFloat(), net.ReadFloat(), net.ReadFloat())

        if game.SinglePlayer() then
            BulletInfo.Settings = {
                Speed = Speed or BulletPhysics.Settings.Projectiles.DefaultSpeed,
                Gravity = Gravity or BulletPhysics.Settings.Projectiles.Gravity,
                ShouldBounce = BulletPhysics.Settings.Projectiles.ShouldBounce,
                EnableSounds = BulletPhysics.Settings.Projectiles.EnableSounds
            }
        end

        local Manager = BulletPhysicsProjectileSystem:GetGlobalManager()
        local Projectile = Manager:CreateProjectile(BulletInfo)
        Projectile.ShouldFireBulletOnHit = false
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
    -- Checks if the weapon is detoured in the settings
    if IsCurrentWeaponDetoured(self) then
        BulletInfo.TracerName = "Projectile"
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
    
    local Settings = {
        Speed = BulletPhysics.Settings.Projectiles.DefaultSpeed,
        Gravity = BulletPhysics.Settings.Projectiles.Gravity,
        ShouldBounce = BulletPhysics.Settings.Projectiles.ShouldBounce,
        EnableSounds = BulletPhysics.Settings.Projectiles.EnableSounds
    }
    if BulletInfo.Settings then
        Settings.Speed = BulletInfo.Settings.Speed
        Settings.Gravity = BulletInfo.Settings.Gravity
    end
    BulletInfo.Settings = Settings
    
    -- Shoot many bullets
    local Num = BulletInfo.Num or 1
    for NumBullets = 1, Num do
        -- Save bullet.dir for later so we can revert back after
        local Dir = BulletInfo.Dir

        ProjectileInfo:CalculateSpread(BulletInfo, engine.TickCount(), NumBullets)

        if self:IsPlayer() then
            -- Get the player's assigned manager
            local Manager = self:GetProjectileManager()

            Manager:CreateProjectile(BulletInfo)
        elseif SERVER then
            -- Gets the serverside manager
            local Manager = BulletPhysicsProjectileSystem:GetGlobalManager()
            Manager:CreateProjectile(BulletInfo)
        end

        -- Revert back
        BulletInfo.Dir = Dir
    end
end

-- Override bullets from engine weapons
hook.Add("PostEntityFireBullets", HookIndentifier .. "FireBullets", function(Entity, BulletInfo)
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

    hook.Add("PostDrawOpaqueRenderables", HookIndentifier .. "ProjectileRender", function()
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

BulletPhysics.AmmoTypeCache = {}
function BulletPhysics:GetAmmoTypeDamage(AmmoID)
    -- Attempt to return a cached value first.
    if self.AmmoTypeCache[AmmoID] then return self.AmmoTypeCache[AmmoID] end
    -- Set the cached variable for appropriate ammo type.
    self.AmmoTypeCache[AmmoID] = game.GetAmmoPlayerDamage(AmmoID)

    return self.AmmoTypeCache[AmmoID]
end