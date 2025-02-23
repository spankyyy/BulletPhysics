AddCSLuaFile()

include("ballistica/core/extranet.lua")
include("ballistica/core/debug.lua")

local Ballistica = {}
Ballistica.__index = Ballistica
_G.Ballistica = Ballistica

Ballistica.ProjectileTypes = {}
Ballistica.Projectiles = {}
Ballistica.ProjectileCount = 0
Ballistica.PlayerTickCounts = {}

Ballistica.LagCompensationEnabled = true

if not game.SinglePlayer() then
    Ballistica.LagCompensation = include("ballistica/core/lagcompensation.lua")
end

local DefaultClassName = "base_projectile"
function Ballistica:CreateProjectile(BulletInfo, ClassName)

    local ClassName = ClassName or DefaultClassName
    local Projectile = self.ProjectileTypes[ClassName]

    if not Projectile then
        ClassName = DefaultClassName
        Projectile = self.ProjectileTypes[ClassName]
    end

    local NewProjectile = Projectile:New(BulletInfo)
    
    table.insert(Ballistica.Projectiles, NewProjectile)

    local Index = #Ballistica.Projectiles + 1

    Ballistica.ProjectileCount = Ballistica.ProjectileCount + 1 -- Projectile Count
    NewProjectile.Index = Index

    -- Lag compensation stuff
    NewProjectile:SetTickCount(engine.TickCount())

    local Attacker = BulletInfo.Attacker
    if SERVER and IsValid(Attacker) and Attacker:IsPlayer() and Ballistica.LagCompensationEnabled and not game.SinglePlayer() then
        local _TickCount = Ballistica.PlayerTickCounts[Attacker:EntIndex()]
        NewProjectile:SetTickCount(_TickCount)
    end

    NewProjectile:AddFilter(BulletInfo.Filter)


    hook.Call("OnProjectileCreated", nil, NewProjectile)
    return NewProjectile
end

function Ballistica:RemoveProjectile(Projectile, Index)
    table.remove(Ballistica.Projectiles, Index)
    Ballistica.ProjectileCount = Ballistica.ProjectileCount - 1
    Projectile:Remove()
end

function Ballistica:Reset()
    self.Projectiles = {}
    self.ProjectileCount = 0
end


if SERVER then
    util.AddNetworkString("Ballistica_NetworkProjectiles")
    hook.Add("OnProjectileCreated", "Ballistica_OnProjectileCreated", function(Projectile)
        net.Start("Ballistica_NetworkProjectiles", true)
            net.WriteString(Projectile.Name)
            net.WriteEntity(Projectile.BulletInfo.Attacker)
            net.WriteFloat(Projectile.BulletInfo.Speed or 0)
            net.WriteVectorFloat(Projectile.BulletInfo.Dir)
            net.WriteVectorFloat(Projectile.BulletInfo.Src)
        net.OmitBroad(Projectile.BulletInfo.Attacker)
    end)
end

local LocalPlayerPing = 0
local PingStartTime = SysTime()

if CLIENT then
    net.Receive("Ballistica_NetworkProjectiles", function()
        local BulletInfo = {}
        local ClassName = net.ReadString()
        BulletInfo.Attacker = net.ReadEntity()
        BulletInfo.Speed = net.ReadFloat()
        BulletInfo.Dir = net.ReadVectorFloat()
        BulletInfo.Src = net.ReadVectorFloat()

        
        Ballistica:CreateProjectile(BulletInfo, ClassName)
    end)
end

-- get a path to every file in lua/ballistica/projectiles and exclude base_projectile
local function IncludeFiles()
    Ballistica:Reset()

    -- Load base
    Ballistica.ProjectileTypes = {}
    Ballistica.ProjectileTypes[DefaultClassName] = include("ballistica/projectiles/base_projectile.lua")

    local ProjectilePath = "ballistica/projectiles/"
    local FilePaths, Dirs = file.Find(ProjectilePath .. "*", "LUA")
    for _, FileName in pairs(FilePaths) do
        local FileName = string.StripExtension(FileName)
        if FileName ~= DefaultClassName then
            local PROJECTILE = include(ProjectilePath .. FileName .. ".lua")

            if not PROJECTILE.Base then continue end
            local Base = Ballistica.ProjectileTypes[PROJECTILE.Base]

            if Base ~= nil and Base ~= "" then
                table.Inherit(PROJECTILE, Base)
            end 

            Ballistica.ProjectileTypes[FileName] = PROJECTILE
        end
    end
end
IncludeFiles()

local TimeCache = {}
timer.Create("Ballistica_AutoRefresh", 1, 0, function()
    local Any = false
    local ProjectilePath = "ballistica/projectiles/"
    local FilePaths, Dirs = file.Find(ProjectilePath .. "*", "LUA")
    for _, FileName in pairs(FilePaths) do
        local FileName = string.StripExtension(FileName)
        local Time = file.Time(ProjectilePath .. FileName .. ".lua", "LUA")

        if TimeCache[FileName] ~= nil and Time ~= TimeCache[FileName] then
            Any = true
            print("Ballistica Autoreload File: " .. ProjectilePath .. FileName .. ".lua")
        end

        TimeCache[FileName] = Time
        if Any then break end
    end

    if Any then timer.Simple(0.1, IncludeFiles) end
end)

local simulationtime = 0
local renderingtime = 0

if SERVER and Ballistica.LagCompensationEnabled and not game.SinglePlayer() then
    
    hook.Add("SetupMove", "Ballistica_GatherPlayerTickCounts", function(Ply, _, CUserCMD)
        if not IsFirstTimePredicted() then return end
        if not IsValid(Ply) then return end
        if not IsValid(CUserCMD) then return end

        
        Ballistica.PlayerTickCounts[Ply:EntIndex()] = CUserCMD:TickCount()
    end)

    hook.Add("Tick", "Ballistica_OnTickPredicted", function()
        local Begin = SysTime()
        for Index, Projectile in ipairs(Ballistica.Projectiles) do
            if Index == 0 then continue end
            local Attacker = Projectile.Attacker
            if not IsValid(Attacker) then 
                Ballistica:RemoveProjectile(Projectile, Index)
                continue 
            end

            if Attacker:IsPlayer() and not Projectile.Virtual then
                Ballistica.LagCompensation:StartLagCompensation(Attacker)
                Ballistica.LagCompensation:BacktrackTo(Projectile:GetTargetCompensationTick())
        
                Projectile:Simulate()
        
                Ballistica.LagCompensation:QueryRaycast(Projectile.MoveTrace)
        
                if Projectile.Deleting or not Projectile.Valid then
                    Ballistica:RemoveProjectile(Projectile, Index)
                    continue
                end
        
                if Projectile.MoveTrace.Hit then
                    Projectile:OnHit()
                end
                Ballistica.LagCompensation:EndLagCompensation()
            else
                Projectile:Simulate()
    
                if Projectile.Deleting or not Projectile.Valid then
                    Ballistica:RemoveProjectile(Projectile, Index)
                    continue
                end
        
                if Projectile.MoveTrace.Hit then
                    Projectile:OnHit()
                end
            end
        end
        simulationtime = SysTime() - Begin
    end)
else
    --hook.Remove("Tick", "Ballistica_OnTickPredicted")
    hook.Add("Tick", "Ballistica_OnTick", function()
        local Begin = SysTime()
        for Index, Projectile in ipairs(Ballistica.Projectiles) do
            if Index == 0 then continue end
            Projectile:Simulate()
    
            if Projectile.Deleting or not Projectile.Valid then
                Ballistica:RemoveProjectile(Projectile, Index)
            end
    
            if Projectile.MoveTrace.Hit then
                Projectile:OnHit()
            end
        end
        simulationtime = SysTime() - Begin
    end)
end

-- My Rendering
if CLIENT then
    rendered_this_frame = 0
    last_skipped_renders = 0
    culled_this_frame = 0
    hook.Add("PostDrawTranslucentRenderables", "Ballistica_OnProjectileRender", function(DrawingDepth, DrawingSkybox, Drawing3DSkybox)
        if DrawingSkybox or Drawing3DSkybox then return end

        rendered_this_frame = 0
        culled_this_frame = 0

        local Begin = SysTime()
        for Index, Projectile in ipairs(Ballistica.Projectiles) do
            --if not Projectile.Valid then continue end
            --if Projectile.Virtual then continue end

            Projectile:InterpolatePositions()
            local Culled = Projectile:Render()
            --Projectile:InterpolatePositions()

            culled_this_frame = culled_this_frame + (Culled and 1 or 0)
            rendered_this_frame = rendered_this_frame + 1
        end
        renderingtime = SysTime() - Begin
    end)
end


print(GetConVar("ballistica_debug"):GetBool())
if CLIENT then
    function draw.TextFull(tbl)
        draw.TextShadow(tbl, tbl.distance, tbl.alpha)
        draw.Text(tbl)
    end
    surface.CreateFont( "Ballistica_Font", {
        font = "Roboto", --  Use the font-name which is shown to you by your operating system Font Viewer, not the file name
        extended = false,
        size = 24,
        weight = 0,
        blursize = 0,
        scanlines = 2,
        antialias = true,
        underline = false,
        italic = false,
        strikeout = false,
        symbol = false,
        rotary = false,
        shadow = false,
        additive = false,
        outline = false,
    } )

    local frametimecache = {}
    hook.Add("HUDPaint", "Ballistica_HudPaint", function()
        if not GetConVar("ballistica_debug"):GetBool() then return end

        draw.TextFull( {
            text = "Projectiles Count: " .. last_skipped_renders + rendered_this_frame,
            font = "Ballistica_Font",
            distance = 2,
            alpha = 255,
            pos = { 50, 50 }
        } )

        draw.TextFull( {
            text = "Skipped Projectiles: " .. last_skipped_renders,
            font = "Ballistica_Font",
            distance = 2,
            alpha = 255,
            pos = { 50, 75 }
        } )

        draw.TextFull( {
            text = "Culled Projectiles: " .. culled_this_frame,
            font = "Ballistica_Font",
            distance = 2,
            alpha = 255,
            pos = { 50, 100 }
        } )

        draw.TextFull( {
            text = "Rendered Projectiles: " .. rendered_this_frame - culled_this_frame,
            font = "Ballistica_Font",
            distance = 2,
            alpha = 255,
            pos = { 50, 125 }
        } )



        local ft = RealFrameTime()
        table.insert(frametimecache, ft)
        local count = #frametimecache
        if count > 8 then
            table.remove(frametimecache, 1)
        end

        local average = 0
        for k,v in ipairs(frametimecache) do
            average = average + v
        end
        average = average / count

        local y = 175
        draw.TextFull( {
            text = "Frametime: " .. math.Round(RealFrameTime() * 1000) .. "ms",
            font = "Ballistica_Font",
            distance = 2,
            alpha = 255,
            pos = { 50, y }
        } )
        y = y + 25

        draw.TextFull( {
            text = "Frametime (8 Frame Average): " .. math.Round(average * 1000) .. "ms",
            font = "Ballistica_Font",
            distance = 2,
            alpha = 255,
            pos = { 50, y }
        } )
        y = y + 25

        draw.TextFull( {
            text = "Total Time: " .. math.Round((simulationtime + renderingtime) * 1000) .. "ms",
            font = "Ballistica_Font",
            distance = 2,
            alpha = 255,
            pos = { 50, y }
        } )
        y = y + 25

        draw.TextFull( {
            text = "Simulation Time: " .. math.Round(simulationtime * 1000) .. "ms",
            font = "Ballistica_Font",
            distance = 2,
            alpha = 255,
            pos = { 50, y }
        } )
        y = y + 25

        draw.TextFull( {
            text = "Rendering Time: " .. math.Round(renderingtime * 1000) .. "ms",
            font = "Ballistica_Font",
            distance = 2,
            alpha = 255,
            pos = { 50, y }
        } )
        y = y + 50

        draw.TextFull( {
            text = "Ping: " .. LocalPlayer():Ping() .. "ms",
            font = "Ballistica_Font",
            distance = 2,
            alpha = 255,
            pos = { 50, y}
        } )
        y = y + 25

        draw.TextFull( {
            text = "Lag Compensation Ticks Behind: " .. math.Round(LocalPlayer():Ping() / 15 / 2) .. " ticks (" .. LocalPlayer():Ping() * 0.5 .. "ms)",
            font = "Ballistica_Font",
            distance = 2,
            alpha = 255,
            pos = { 50, y}
        } )
        y = y + 25
    end)
end
