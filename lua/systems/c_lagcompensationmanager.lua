AddCSLuaFile()
-- make backtracking
--if CLIENT then return end

local C_LagCompensationManager = {}
C_LagCompensationManager.__index = C_LagCompensationManager
_G.C_LagCompensationManager = C_LagCompensationManager

C_LagCompensationManager.CompensationBufferLength = 66
C_LagCompensationManager.CompensationBuffer = {}

C_LagCompensationManager.CompensationTarget = 0
C_LagCompensationManager.CompensatingFor = NULL
C_LagCompensationManager.CompensationInProgress = false

-- Gets the player metatable
PlayerMeta = FindMetaTable("Player")


local function RenderHitbox(Hitbox)
    if not Hitbox then return end
    for k,v in pairs(Hitbox) do
        if SERVER then
            debugoverlay.BoxAngles(v.Position, v.Min, v.Max, v.Angle, 0, Color(255, 196, 128, 64))
        else
            debugoverlay.BoxAngles(v.Position, v.Min, v.Max, v.Angle, 0, Color(128, 196, 255, 0))

            local Pos = (v.Max + v.Min) * 0.5
            Pos:Rotate(v.Angle)
            Pos = Pos + v.Position
            debugoverlay.EntityTextAtPosition(Pos, 0, "" .. (k - 1), 0, Color(255, 255, 255) )
            debugoverlay.Sphere(Pos, 0.1, 0, Color(255, 255, 255, 0), true)
        end
    end
end

function PlayerMeta:GetPlayerHitboxes()
    local HitBox = {}
    local I = 1

    if not self:GetHitBoxGroupCount() then return HitBox end


    for group = 0, self:GetHitBoxGroupCount() - 1 do
        for hitbox = 0, self:GetHitBoxCount(group) - 1 do

            local pos, ang =  self:GetBonePosition(self:GetHitBoxBone(hitbox, group))
            local mins, maxs = self:GetHitBoxBounds(hitbox, group)

            HitBox[I] = {
                Position = pos,
                Angle = ang,
                Min = mins,
                Max = maxs
            }
            I = I + 1
        end
    end
    return HitBox
end

function C_LagCompensationManager:SavePlayerHitboxState(Player)
    local Hitbox = Player:GetPlayerHitboxes()
    local PlayerIndex = Player:EntIndex()

    -- Get the player's aabb

    local ScaleAdd = Vector(16, 16, 16)
    local AABB = {
        Position = Player:GetPos(),
        Angle = Angle(0, 0, 0),
        Min = Player:OBBMins() - ScaleAdd,
        Max = Player:OBBMaxs() + ScaleAdd
    }

    -- Create a buffer for the player if its not already done
    self.CompensationBuffer[PlayerIndex] = self.CompensationBuffer[PlayerIndex] or {}
    self.CompensationBuffer[PlayerIndex][0] = self.CompensationBuffer[PlayerIndex][0] or 0

    local PlayerBuffer = self.CompensationBuffer[PlayerIndex]

    -- Table length is stored in 0
    if PlayerBuffer[0] >= self.CompensationBufferLength then
        table.remove(PlayerBuffer, 1)
        PlayerBuffer[0] = PlayerBuffer[0] - 1
    end
    table.insert(PlayerBuffer, {AABB, Hitbox})
    PlayerBuffer[0] = PlayerBuffer[0] + 1
end

function C_LagCompensationManager:GetPlayerHitboxState(Player, TargetTick)
    local PlayerIndex = Player:EntIndex()
    local PlayerBuffer = self.CompensationBuffer[PlayerIndex]
    if not PlayerBuffer then return end

    local CurrentTick = engine.TickCount()
    local TickDifference = CurrentTick - TargetTick

    local ChosenIndex = math.Clamp(C_LagCompensationManager.CompensationBufferLength - TickDifference, 1, PlayerBuffer[0])

    local ChosenHitbox = PlayerBuffer[ChosenIndex]
    return ChosenHitbox
end

function C_LagCompensationManager:GetPlayerHitboxStates(TargetTick)
    local States = {}
    local I = 1
    for k, Ply in pairs(player.GetAll()) do
        local State = C_LagCompensationManager:GetPlayerHitboxState(Ply, TargetTick)
        States[I] = {Ply, State}
        I = I + 1
    end 
    return States
end

function C_LagCompensationManager:BacktrackTo(TargetTick)
    if not self.CompensationInProgress then return end

    local Interp = math.floor(0.5 + (self:GetInterpolationAmount() / engine.TickInterval()))
    self.CompensationTarget = TargetTick - Interp
end

function C_LagCompensationManager:StartLagCompensation(Ply)
    self.CompensatingFor = Ply
    self.CompensationInProgress = true
end

function C_LagCompensationManager:EndLagCompensation()
    self.CompensatingFor = nil
    self.CompensationInProgress = false
end

function C_LagCompensationManager:AskForInterp(Ply)
    net.Start("LagCompInterp")
    net.Send(Ply)
end

local sv_minupdaterate = GetConVar("sv_minupdaterate")
local sv_maxupdaterate = GetConVar("sv_maxupdaterate")
local sv_client_min_interp_ratio = GetConVar("sv_client_min_interp_ratio")
local sv_client_max_interp_ratio = GetConVar("sv_client_max_interp_ratio")
function C_LagCompensationManager:GetInterpolationAmount()
    local Ply = C_LagCompensationManager.CompensatingFor
    local Interps = Ply.Interps
    if not Interps then 
        return 0
    end
    
    local iUpdateRate = math.Clamp(Interps.cl_updaterate, sv_minupdaterate:GetInt(), sv_maxupdaterate:GetInt())
    local flLerpRatio = math.max(1, Interps.cl_interp_ratio)
    local flLerpAmount = Interps.cl_interp


    if sv_client_min_interp_ratio:GetFloat() ~= -1 then
        flLerpRatio = math.Clamp(flLerpRatio, sv_client_min_interp_ratio:GetFloat(), sv_client_max_interp_ratio:GetFloat())
    end

    return math.max(flLerpAmount, flLerpRatio / iUpdateRate)
end

if SERVER then
    -- Network string for sending bullets to clients
    util.AddNetworkString("LagCompInterp")

    hook.Add("Tick", "LagComensationHitboxStates", function()
        for k,v in pairs(player.GetAll()) do
            C_LagCompensationManager:SavePlayerHitboxState(v)
        end 
    end)

    net.Receive("LagCompInterp", function(len, ply)
        local cl_interp = net.ReadFloat()
        local cl_interp_ratio = net.ReadFloat()
        local cl_updaterate = net.ReadFloat()

        ply.Interps = ply.Interps or {}

        ply.Interps.cl_interp = cl_interp
        ply.Interps.cl_interp_ratio = cl_interp_ratio
        ply.Interps.cl_updaterate = cl_updaterate
    end)

    hook.Add("PlayerInitialSpawn", "LagComensationGetInterps", function(Player)
        C_LagCompensationManager:AskForInterp(Player)
    end)

    for _, Player in pairs(player.GetAll()) do
        C_LagCompensationManager:AskForInterp(Player)
    end

end

if CLIENT then
    net.Receive("LagCompInterp", function()
        local cl_interp = GetConVar("cl_interp"):GetFloat()
        local cl_interp_ratio = GetConVar("cl_interp_ratio"):GetFloat()
        local cl_updaterate = GetConVar("cl_updaterate"):GetInt()

        net.Start("LagCompInterp")
            net.WriteFloat(cl_interp)
            net.WriteFloat(cl_interp_ratio)
            net.WriteFloat(cl_updaterate)
        net.SendToServer()
    end)
end
