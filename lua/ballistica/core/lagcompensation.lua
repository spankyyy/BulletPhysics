AddCSLuaFile()

--if CLIENT then return end

local LagCompensation = {}
LagCompensation.__index = LagCompensation

if SERVER then
    LagCompensation.CompensationBufferLength = 66
    LagCompensation.CompensationBuffer = {}
    LagCompensation.BufferLengths = {}

    LagCompensation.CompensationTolerance = 1 -- multiplies the size of the hitboxes
    LagCompensation.CompensationWindowLength = 1 -- (n * 2 + 1) how many extra ticks forward and backwards in time does the lagcomp try 
    LagCompensation.CompensationTarget = 0


    LagCompensation.CompensatingFor = NULL
    LagCompensation.CompensationInProgress = false

    local DGB = false
    function dbgprint(...)
        if not DGB then return end
        print(...)
    end

    local function RenderHitbox(Hitbox, time, showtolerance)
        if not Hitbox then return end
        for k,v in pairs(Hitbox) do
            if SERVER then
                debugoverlay.BoxAngles(v.Position, v.Min, v.Max, v.Angle, time or 1, Color(255, 255, 255, 0))

                if showtolerance then
                    local Tol = LagCompensation.CompensationTolerance
                    debugoverlay.BoxAngles(v.Position, v.Min * Tol, v.Max * Tol, v.Angle, time or 1, Color(255, 0, 0, 0))
                end
            end
        end
    end

    local function PingPongIndex(Index, AddIndex)
        local Even = AddIndex % 2 == 0
        local AddIndex = math.ceil(AddIndex / 2)
        if Even then
            AddIndex = -AddIndex
        end
    
        return Index + AddIndex
    end


    PlayerMeta = FindMetaTable("Player")

    function PlayerMeta:GetPlayerHitboxes()
        local HitBox = {}
        local I = 1

        if not self:GetHitBoxGroupCount() then return HitBox end

        for group = 0, self:GetHitBoxGroupCount() - 1 do
            for hitbox = 0, self:GetHitBoxCount(group) - 1 do

                local pos, ang = self:GetBonePosition(self:GetHitBoxBone(hitbox, group))
                local mins, maxs = self:GetHitBoxBounds(hitbox, group)
                local group = self:GetHitBoxHitGroup(hitbox, group)

                HitBox[I] = {
                    Position = pos,
                    Angle = ang,
                    Group = group,
                    Min = mins,
                    Max = maxs
                }

                I = I + 1
            end
        end
        return HitBox
    end

    function LagCompensation:SavePlayerHitboxState(Player)
        local Hitbox = Player:GetPlayerHitboxes()
        local PlayerIndex = Player:EntIndex()

        -- Get the player's aabb

        local ScaleAdd = Vector(24, 24, 24)
        local AABB = {
            Position = Player:GetPos(),
            Angle = Angle(0, 0, 0),
            Min = Player:OBBMins() - ScaleAdd,
            Max = Player:OBBMaxs() + ScaleAdd
        }

        -- Create a buffer for the player if its not already done
        self.CompensationBuffer[PlayerIndex] = self.CompensationBuffer[PlayerIndex] or {}
        self.BufferLengths[PlayerIndex] = self.BufferLengths[PlayerIndex] or 0

        if Player:Alive() then
            local PlayerBuffer = self.CompensationBuffer[PlayerIndex]

            -- Table length is stored in 0
            if self.BufferLengths[PlayerIndex] >= self.CompensationBufferLength then
                table.remove(PlayerBuffer, 1)
                self.BufferLengths[PlayerIndex] = self.BufferLengths[PlayerIndex] - 1
            end
            table.insert(PlayerBuffer, {AABB, Hitbox})
            self.BufferLengths[PlayerIndex] = self.BufferLengths[PlayerIndex] + 1
        else
            self.CompensationBuffer[PlayerIndex] = {}
            self.BufferLengths[PlayerIndex] = 0
        end
    end

    function LagCompensation:GetPlayerHitboxState(Player, TargetTick)
        local PlayerIndex = Player:EntIndex()
        local PlayerBuffer = self.CompensationBuffer[PlayerIndex]
        if not PlayerBuffer then return end

        local CurrentTick = engine.TickCount()
        local TickDifference = CurrentTick - TargetTick

        local ChosenIndex = math.Clamp(LagCompensation.CompensationBufferLength - TickDifference, 1, self.BufferLengths[PlayerIndex] or 1)

        local ChosenHitbox = PlayerBuffer[ChosenIndex]
        return ChosenHitbox
    end

    function LagCompensation:GetPlayerHitboxStates(TargetTick)
        local States = {}

        for i, Ply in player.Iterator() do
            local State = LagCompensation:GetPlayerHitboxState(Ply, TargetTick)

            table.insert(States, {Ply, State})
        end

        return States
    end

    function LagCompensation:BacktrackTo(TargetTick)
        if not self.CompensationInProgress then return end

        local Interp = math.floor(0.5 + (self:GetInterpolationAmount() / engine.TickInterval() * 1.5))
        self.CompensationTarget = TargetTick - math.Round(Interp * 0.5) + 1
    end

    function LagCompensation:StartLagCompensation(Player)
        self.CompensatingFor = Player
        self.CompensationInProgress = true
    end

    function LagCompensation:EndLagCompensation()
        self.CompensatingFor = nil
        self.CompensationInProgress = false
    end



    function LagCompensation:QueryRaycast(Trace)
        -- Player who called the query
        local QueryCaller = LagCompensation.CompensatingFor
        local Tolerance = math.max(1, LagCompensation.CompensationTolerance)

        local CompensationTarget = LagCompensation.CompensationTarget
        local TryCount = LagCompensation.CompensationWindowLength * 2

        dbgprint("Starting Compensation with " .. TryCount+1 .. " Attempts")
        for Try=0, TryCount do
            --local CompensationTarget = CompensationTarget - (TryCount * .5) + Try
            local CompensationTarget = PingPongIndex(CompensationTarget, Try)

            -- Get the hitbox states of every player
            local HitboxStates = LagCompensation:GetPlayerHitboxStates(CompensationTarget)
            if not HitboxStates then return end
            -- {1 = {Ply, {AABB, Hitbox}}}


            -- Get trace length
            local TraceLength = Trace.StartPos:Distance(Trace.HitPos)

            -- Trace stuff
            local Entity, Pos, Normal, HitGroup
            local HitBoxID, Frac = 0, 1

            -- Hitbox intersection
            for k, Hitboxes in pairs(HitboxStates) do
                if not Hitboxes then continue end

                local Ply = Hitboxes[1]

                -- Dont query if the player is caller
                if QueryCaller == Ply then continue end
                if not Ply:Alive() then continue end
                if Trace.Entity == Ply then continue end

                
                -- Optimization check to limit the amount of obb intersections


                local AABB = Hitboxes[2][1]
                local Hit = util.IntersectRayWithOBB(Trace.StartPos, Trace.Normal * TraceLength, AABB.Position, AABB.Angle, AABB.Min, AABB.Max)
                if not Hit then
                    dbgprint("Compensation Unsuccessful: bro so bad he missed by a mile")
                    continue 
                end

                -- Loop tru all hitboxes
                RenderHitbox(LagCompensation:GetPlayerHitboxState(Ply, 99999999)[2], 5, false)

                RenderHitbox(Hitboxes[2][2], 1, true)

                debugoverlay.Line(Trace.StartPos, Trace.HitPos, 1, Color(0, 255, 0), true)

                for k, Hitbox in pairs(Hitboxes[2][2]) do
                    if not Hitbox then continue end
                    Hitpos, Hitnormal, Fraction = util.IntersectRayWithOBB(Trace.StartPos, Trace.Normal * TraceLength, Hitbox.Position, Hitbox.Angle, Hitbox.Min * Tolerance, Hitbox.Max * Tolerance)
                    if Hitpos and Fraction < Frac then
                        HitBoxID, HitGroup, Entity, Pos, Normal, Frac = k, Hitbox.Group, Ply, Hitpos, Hitnormal, Fraction
                    end
                end
                
            end


            -- If the intersection was successfull then we change the traceresult and break the loop
            if (Pos ~= nil) then
                dbgprint("Compensation successful: Hit")
                dbgprint("Tries: " .. Try+1)
                dbgprint("Entity: " .. Entity:EntIndex())
                dbgprint("HitboxID: " .. HitBoxID)
                
                debugoverlay.Sphere(Pos, 3, 5, Color(255, 0, 0, 0), true)

                Trace.Hit = true 
                Trace.HitPos = Pos
                Trace.HitNormal = Normal
                Trace.Fraction = Frac
                Trace.HitGroup = HitGroup
                Trace.HitBox = HitBoxID
                Trace.Entity = Entity
                break -- Break the loop since a hit was successfull
            else
                dbgprint("Compensation Unsuccessful: bro so fucking bad he missed by an ass hair")
            end
        end
    end

    -- Network string for sending bullets to clients
    util.AddNetworkString("LagCompensationInterpConvars")
    util.AddNetworkString("LagCompensationClientReady")

    function LagCompensation:AskForInterp(Ply)
        net.Start("LagCompensationInterpConvars")
        net.Send(Ply)
    end

    local sv_minupdaterate = GetConVar("sv_minupdaterate")
    local sv_maxupdaterate = GetConVar("sv_maxupdaterate")
    local sv_client_min_interp_ratio = GetConVar("sv_client_min_interp_ratio")
    local sv_client_max_interp_ratio = GetConVar("sv_client_max_interp_ratio")
    function LagCompensation:GetInterpolationAmount()
        local Ply = LagCompensation.CompensatingFor
        local Interps = Ply.Interps
        if not Interps then return 0 end
        
        local iUpdateRate = math.Clamp(Interps.cl_updaterate, sv_minupdaterate:GetInt(), sv_maxupdaterate:GetInt())
        local flLerpRatio = math.max(1, Interps.cl_interp_ratio)
        local flLerpAmount = Interps.cl_interp

        if sv_client_min_interp_ratio:GetFloat() ~= -1 then
            flLerpRatio = math.Clamp(flLerpRatio, sv_client_min_interp_ratio:GetFloat(), sv_client_max_interp_ratio:GetFloat())
        end

        return math.max(flLerpAmount, flLerpRatio / iUpdateRate)
    end

    hook.Add("Tick", "LagComensationHitboxStates", function()
        for _, Ply in player.Iterator() do
            LagCompensation:SavePlayerHitboxState(Ply)
        end
    end)

    net.Receive("LagCompensationInterpConvars", function(_, ply)
        local cl_interp = net.ReadFloat()
        local cl_interp_ratio = net.ReadFloat()
        local cl_updaterate = net.ReadFloat()

        ply.Interps = ply.Interps or {}

        ply.Interps.cl_interp = cl_interp
        ply.Interps.cl_interp_ratio = cl_interp_ratio
        ply.Interps.cl_updaterate = cl_updaterate
    end)

    net.Receive("LagCompensationClientReady", function(_, Player)
        LagCompensation:AskForInterp(Player)
    end)

    -- ask for interp every 10 seconds
    timer.Create("LagComensationGetInterps", 10, 0, function()
        for _, Ply in player.Iterator() do
            LagCompensation:AskForInterp(Ply)
        end
    end)

    for _, Ply in player.Iterator() do
        LagCompensation:AskForInterp(Ply)
    end
end

if CLIENT then
    hook.Add("InitPostEntity", "LagCompensationClientReady", function()
        net.Start("LagCompensationClientReady")
        net.SendToServer()
    end)

    net.Receive("LagCompensationInterpConvars", function()
        local cl_interp = GetConVar("cl_interp"):GetFloat()
        local cl_interp_ratio = GetConVar("cl_interp_ratio"):GetFloat()
        local cl_updaterate = GetConVar("cl_updaterate"):GetInt()
        net.Start("LagCompensationInterpConvars")
            net.WriteFloat(cl_interp)
            net.WriteFloat(cl_interp_ratio)
            net.WriteFloat(cl_updaterate)
        net.SendToServer()
    end)
end

return LagCompensation