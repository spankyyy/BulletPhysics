AddCSLuaFile()
-- query a raycast from a certain tick count

local C_HitboxSystem = {}
C_HitboxSystem.__index = C_HitboxSystem
_G.C_HitboxSystem = C_HitboxSystem

function GetPlayerHitboxes(self)
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
-- Save hitboxes of every player
-- Buffer length DEF 1 second

-- Calling queryRaycast() will query a raycast to the hitboxes
-- Will modify traceresults inputted
-- Use lag compensation to get every players hitbox at a tick

local function RenderHitboxes(Hitbox, T)
    if not Hitbox then return end
    for k,v in pairs(Hitbox) do
        if T then
            debugoverlay.BoxAngles(v.Position, v.Min, v.Max, v.Angle, 4, Color(255, 196, 128, 64))
        else
            debugoverlay.BoxAngles(v.Position, v.Min, v.Max, v.Angle, 4, Color(128, 196, 255, 64))
        end
    end
end

local function RenderHitbox(Hitbox)
    if not Hitbox then return end
    if SERVER then
        debugoverlay.BoxAngles(Hitbox.Position, Hitbox.Min, Hitbox.Max, Hitbox.Angle, 1, Color(255, 196, 128, 64))
    else
        debugoverlay.BoxAngles(Hitbox.Position, Hitbox.Min, Hitbox.Max, Hitbox.Angle, 1, Color(128, 196, 255, 0))
    end
end

function C_HitboxSystem:QueryRaycast(Trace, OnHit)
    -- Player who called the query
    local QueryCaller = C_LagCompensationManager.CompensatingFor

    -- Get the hitbox states of every player
    local HitboxStates = C_LagCompensationManager:GetPlayerHitboxStates(C_LagCompensationManager.CompensationTarget)
    if not HitboxStates then return end

    -- Get trace length
    local TraceLength = Trace.StartPos:Distance(Trace.HitPos)

    -- Trace stuff
    local Entity, Pos, Normal
    local HitBoxID, Frac = 0, 1

    -- Hitbox intersection
    for _, Hitboxes in pairs(HitboxStates) do
        if not Hitboxes then continue end
        local Ply = Hitboxes[1]

        -- Dont query if the player is caller
        if QueryCaller == Ply then continue end
        
        -- Optimization check to limit the amount of obb intersections
        local AABB = Hitboxes[2][1]
        local Hit = util.IntersectRayWithOBB(Trace.StartPos, Trace.Normal * TraceLength, AABB.Position, AABB.Angle, AABB.Min, AABB.Max)
        if not Hit then continue end

        -- Loop tru all hitboxes
        for k, Hitbox in pairs(Hitboxes[2][2]) do
            if not Hitbox then continue end
            Hitpos, Hitnormal, Fraction = util.IntersectRayWithOBB(Trace.StartPos, Trace.Normal * TraceLength, Hitbox.Position, Hitbox.Angle, Hitbox.Min, Hitbox.Max)

            if Hitpos and Fraction < Frac then
                HitBoxID, Entity, Pos, Normal, Frac = k, Ply, Hitpos, Hitnormal, Fraction
            end
        end
    end


    -- If the intersection was successfull then we change the traceresult and run onhit
    if (Pos ~= nil) then
        Trace.Hit = true 
        Trace.HitPos = Pos
        Trace.HitNormal = Normal
        Trace.Fraction = Frac
        Trace.HitBox = HitBoxID
        Trace.Entity = Entity

        OnHit()
    elseif Trace.Hit then
        OnHit()
    end
end