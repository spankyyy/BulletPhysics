AddCSLuaFile()
-- query a raycast from a certain tick count

local C_HitboxSystem = {}
C_HitboxSystem.__index = C_HitboxSystem
_G.C_HitboxSystem = C_HitboxSystem


-- Save hitboxes of every player
-- Buffer length DEF 1 second

-- Calling queryRaycast() will query a raycast to the hitboxes
-- Will modify traceresults inputted
-- Use lag compensation to get every players hitbox at a tick

local function RenderHitboxes(Hitbox)
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