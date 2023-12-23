AddCSLuaFile()

include("systems/c_hitboxsystem.lua")
include("systems/c_lagcompensationmanager.lua")
include("systems/c_projectilemanager.lua")
include("systems/c_projectilesystem.lua")

local BulletPhysics = {}
_G.BulletPhysics = BulletPhysics

-- Hook name
local HookIndentifier = "BPhys_"
BulletPhysics.HookIdentifier = HookIndentifier
-- Initialize the systems
local BulletPhysicsProjectileSystem = C_ProjectileSystem:New()
BulletPhysics.ProjectileSystem = BulletPhysicsProjectileSystem


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

    -- Make the manager unpredicted (Testing if the code actually works before tackling prediction)
    // trying to tackle prediction might fail
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
    hook.Add("PlayerInitialSpawn", HookIndentifier .. "PlayerSpawned", AssignManager)

    -- Allow for lua refresh
    for _, Player in pairs(player.GetAll()) do
        AssignManager(Player)
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
        BulletInfo.Dir = Vector(net.ReadFloat(), net.ReadFloat(), net.ReadFloat())
        BulletInfo.Src = Vector(net.ReadFloat(), net.ReadFloat(), net.ReadFloat())


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
    for _, Manager in pairs(BulletPhysicsProjectileSystem:GetManagers()) do
        -- Run the manager
        Manager:OnSetupMoveUnpredicted()
    end

    local GlobalManager = BulletPhysicsProjectileSystem:GetGlobalManager()
    GlobalManager:OnSetupMoveUnpredicted()
end)



-- Detours the FireBullets function
EntityMeta = FindMetaTable("Entity")
function EntityMeta:FireBullets(BulletInfo)
    -- Localize BulletInfo to prevent editing of the table outside the function
    local BulletInfo = table.Copy(BulletInfo)

    -- Sets the bullet's attacker
    BulletInfo.Attacker = self

    -- Remove callback function
    BulletInfo.Callback = nil

    -- Move the bullet forward so it doesnt start inside the player's face (Looks better and also fixed a bug).
    
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
        Manager:InterpolateProjectilePositions()

        -- Interpolate global bullets
        local Manager = BulletPhysicsProjectileSystem:GetGlobalManager()
        Manager:InterpolateProjectilePositions()
    end)

    hook.Add("Think", HookIndentifier .. "BulletFlyby", function()
        -- Interpolate local bullets
        local Manager = LocalPlayer():GetProjectileManager()
        Manager:CrackProjectiles()

        -- Interpolate global bullets
        local Manager = BulletPhysicsProjectileSystem:GetGlobalManager()
        Manager:CrackProjectiles()
    end)

    hook.Add("PostDrawOpaqueRenderables", HookIndentifier .. "ProjectileRender", function()
        -- Render localplayer's bullets
        local Manager = LocalPlayer():GetProjectileManager()
        Manager:RenderProjectiles()

        -- Render global bullets
        local Manager = BulletPhysicsProjectileSystem:GetGlobalManager()
        Manager:RenderProjectiles()
    end)
end

BulletPhysics.AmmoTypeCache = {}

function BulletPhysics:GetAmmoTypeDamage(AmmoID)
    -- Attempt to return a cached value first.
    if self.AmmoTypeCache[AmmoID] then return self.AmmoTypeCache[AmmoID] end
    -- Set the cached variable for appropriate ammo type.
    self.AmmoTypeCache[AmmoID] = game.GetAmmoPlayerDamage(AmmoID0)

    return self.AmmoTypeCache[AmmoID]
end