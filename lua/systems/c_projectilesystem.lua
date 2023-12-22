AddCSLuaFile()

local C_ProjectileSystem = {}
C_ProjectileSystem.__index = C_ProjectileSystem
_G.C_ProjectileSystem = C_ProjectileSystem

-- List of all the systems
C_ProjectileSystem.Systems = {}


-- Creates the projectile system
function C_ProjectileSystem:New()
    local self = {}

    self.Managers = {} -- Used for players
    self.GlobalManager = {}
    self = setmetatable(self, C_ProjectileSystem)
    
    -- Add the system to the list
    table.insert(C_ProjectileSystem.Systems, self)

    return self
end


-- Creates a new manager
function C_ProjectileSystem:NewManager()
    local NewManager = C_ProjectileManager:New()

    -- Add the manager to the list
    local Index = table.insert(self.Managers, NewManager)
    NewManager.Index = Index
    
    return NewManager
end

function C_ProjectileSystem:RemoveManager(Manager)
    self.Managers[Manager.Index] = nil
end

function C_ProjectileSystem:GetManagers()
    return self.Managers
end


-- Creates the global manager
function C_ProjectileSystem:CreateGlobalManager()
    local NewManager = C_ProjectileManager:New()
    NewManager:DisablePrediction()

    -- Sets the global manager of the system
    self.GlobalManager = NewManager

    return NewManager
end

-- Gets the global manager
function C_ProjectileSystem:GetGlobalManager()
    return self.GlobalManager
end



