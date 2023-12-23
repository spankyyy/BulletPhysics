AddCSLuaFile()

local ProjectileInfo = {}
ProjectileInfo.__index = ProjectileInfo
_G.ProjectileInfo = ProjectileInfo

-- Create the damage struct and effect data
local ImpactDamage = DamageInfo()
local ImpactEffect = EffectData()
local BounceEffect = EffectData()

// Functions

function util.DistanceToLineFrac(Start, End, Point)
    local Dist = Start:Distance(End)

    local DistToLine, Nearest, Fraction = util.DistanceToLine(Start, End, Point)
    Fraction = math.Clamp(Fraction / Dist, 0, 1)

    return DistToLine, Nearest, Fraction
end

function Spread(Normal, Degrees, Seed, Extra)
    Extra = Extra-1 or 0
    local correctDegrees = 1 - math.cos(math.rad(Degrees))
    local u = util.SharedRandom(Seed, 0, correctDegrees, Extra)
    local v = util.SharedRandom(Seed, 0, 1, Extra + 1)

    local phi = v * 2 * math.pi 
    local cosTheta = math.sqrt(1 - u)
    local sinTheta = math.sqrt(1 - cosTheta * cosTheta)
    local Final = Vector(cosTheta, math.cos(math.deg(phi)) * sinTheta, math.sin(math.deg(phi)) * sinTheta)
    Final:Rotate(Normal:Angle())
    return Final
end


-- Gets the player metatable
PlayerMeta = FindMetaTable("Player")

local VectorZERO = Vector(0, 0, 0)

local DefaultBulletInfo = {
    Attacker = NULL,
    Callback = nil,
    Damage = 1,
    Force = 1,
    Distance = 56756,
    HullSize = 0,
    Num = 1,
    Tracer = 1,
    AmmoType = "",
    Dir = VectorZERO,
    Spread = VectorZERO,
    Src = VectorZERO,
    IgnoreEntity = NULL
}

-- Creates a basic projectile structure

function ProjectileInfo:New()
    local self = {}

    local Default = DefaultBulletInfo
    self.BulletInfo = Default

    -- Projectile specific variables
    self.Position = VectorZERO
    self.LastPosition = VectorZERO
    self.InterpolatedPosition = VectorZERO
    self.Velocity = VectorZERO
    self.Forward = VectorZERO
    self.MoveTrace = {}
    self.TickCount = 0
    self.Attacker = NULL 
    self.First = true
    self.TimeSinceLastSimulation = 0
    self.TickLifetime = 0
    self.ShouldFireBulletOnHit = true
    self.Cracked = false

    -- Variables for the managers
    self.Manager = nil
    self.Index = 0

    return setmetatable(self, ProjectileInfo)
end

-- Setups the projectile structure
function ProjectileInfo:Setup(BulletInfo)
    for k,v in pairs(BulletInfo) do
        self.BulletInfo[k] = v
    end

    if self.BulletInfo.Damage == 0 and self.BulletInfo.AmmoType ~= "" then
        self.AmmoID = game.GetAmmoID(self.BulletInfo.AmmoType)

        --self.BulletInfo.Force = game.GetAmmoForce(self.AmmoID)
    end

    self.BulletInfo.Spread = nil
    self.Position = BulletInfo.Src
    self.InterpolatedPosition = self.Position
    self.TimeAtLastSimulation = UnPredictedCurTime()
    self.LastPosition = self.Position
    self.Velocity = BulletInfo.Dir * (BulletInfo.Speed or 20000)
    self.Forward = self.Velocity:GetNormalized()
    self.Attacker = BulletInfo.Attacker
    self.Bounced = false
    self.MaxBounceAngle = 0.3
end

function ProjectileInfo:CalculateSpread(BulletInfo, Seed, Extra)
    if not BulletInfo.Spread then return end
    BulletInfo.Dir = Spread(BulletInfo.Dir, BulletInfo.Spread[1] * 90, Seed, Extra)
end

function ProjectileInfo:SetTickCount(TickCount)
    self.TickCount = TickCount
end

function ProjectileInfo:GetTickCount()
    return self.TickCount
end

function ProjectileInfo:GetSimulationTick()
    return self.TickLifetime
end

function ProjectileInfo:SetManager(Manager, Index)
    self.Manager = Manager
    self.Index = Index
end

function ProjectileInfo:GetManager()
    return self.Manager
end

function ProjectileInfo:Delete()
    self.Manager:RemoveProjectile(self)
    table.Empty(self)
end

function ProjectileInfo:InterpolatePositions()
    local TimePassed = math.Clamp((UnPredictedCurTime() - self.TimeAtLastSimulation) / engine.TickInterval(), 0, 1)

    self.InterpolatedPosition = LerpVector(TimePassed, self.LastPosition, self.Position)
end

function ProjectileInfo:CalculateDamage(Entity)
    if not self.AmmoID then return self.BulletInfo.Damage end

    local Damage = 0

    if Entity:IsPlayer() or Entity:IsNPC() then
        Damage = BulletPhysics:GetAmmoTypeDamage(self.AmmoID)
    end

    return Damage
end

function ProjectileInfo:FireBullet()
    if not self.MoveTrace.Hit then return end

    local HitEntity = self.MoveTrace.Entity
    if HitEntity and HitEntity:IsValid() and HitEntity ~= self.Attacker and SERVER then
        local CalculatedDamage = self:CalculateDamage(HitEntity)

        local Attacker = self.Attacker
        local Inflictor = self.Attacker
        if self.Attacker:GetOwner():IsValid() then
            Attacker = self.Attacker:GetOwner()
        end
        if self.Attacker:IsPlayer() and self.Attacker:GetActiveWeapon():IsValid() then
            Inflictor = self.Attacker:GetActiveWeapon()
        end

        -- Setup damage
        ImpactDamage:SetDamageType(DMG_BUCKSHOT)
        ImpactDamage:SetAmmoType(self.AmmoID or 0)
        ImpactDamage:SetDamage(CalculatedDamage)
        ImpactDamage:SetDamageForce(self.Forward * self.BulletInfo.Force)
        ImpactDamage:SetAttacker(Attacker)
        ImpactDamage:SetInflictor(Inflictor)
        ImpactDamage:SetReportedPosition(self.MoveTrace.HitPos - self.MoveTrace.Normal)

        -- Apply damage to entity
        HitEntity:TakeDamageInfo(ImpactDamage)
    end

    if not self.Manager:GetPrediction() or CLIENT then
        -- Setup impact effect
        ImpactEffect:SetDamageType(DMG_BUCKSHOT)
        ImpactEffect:SetEntity(HitEntity)
        ImpactEffect:SetOrigin(self.MoveTrace.HitPos)
        ImpactEffect:SetStart(self.Position - self.MoveTrace.Normal * 4)
        ImpactEffect:SetSurfaceProp(self.MoveTrace.SurfaceProps)
        ImpactEffect:SetHitBox(self.MoveTrace.HitBox)

        -- Apply effect
        util.Effect("Impact", ImpactEffect)
    end

    //-- Call callback
    //if self.BulletInfo.Callback then
    //    self.BulletInfo.Callback(self.Attacker, self.MoveTrace, ImpactDamage)
    //end
end

local function Reflect(incident, normal)
    return incident - 2 * (incident:Dot(normal)) * normal
end

local function Squash(vec, planeNormal, scalar)
    return vec - (planeNormal * planeNormal:Dot(vec) * scalar)
end

local function ShouldReflect(self)
    if self.MoveTrace.Entity and self.MoveTrace.Entity:IsValid() then
        local EntityClass = self.MoveTrace.Entity:GetClass()
        if not (EntityClass == "prop_physics" or EntityClass == "worldspawn") then return false end
    end


    local Dot = self.MoveTrace.HitNormal:Dot(-self.Forward:GetNormalized())
    return (Dot < self.MaxBounceAngle) and (self.MoveTrace.Fraction ~= 0)
end

function ProjectileInfo:Simulate()
    //print("Projectile ID:" .. self.Index .. " got simulated.")
    local UpdateRate = engine.TickInterval()
    
    local Velocity = self.Velocity
    util.TraceLine({
        start = self.Position,
        endpos = self.Position + Velocity * UpdateRate,
        filter = self.Attacker,
        mask = MASK_SHOT,
        output = self.MoveTrace
    })


    self.LastPosition = self.Position
    self.Position = self.MoveTrace.HitPos
    self.Forward = Velocity:GetNormalized()

    -- Bounce
    if self.MoveTrace.Hit then
        local Fraction = (1 - self.MoveTrace.Fraction)
        local Hit = false
        for i=1, 16 do
            if not ShouldReflect(self) then break end

            self:OnBounce()

            if not self.MoveTrace.Hit then break end

            util.TraceLine({
                start = self.Position,
                endpos = self.Position + self.Velocity * UpdateRate * Fraction,
                filter = self.Attacker,
                mask = MASK_SHOT,
                output = self.MoveTrace
            })
            self.LastPosition = self.Position
            self.Position = self.MoveTrace.HitPos

            Fraction = Fraction - self.MoveTrace.Fraction

            if Fraction <= 0 then break end
            self.MoveTrace.Hit = false
        end
        self.Forward = Velocity:GetNormalized()
    end

    -- Apply gravity
    local Gravity = Vector(0, 0, -1000) * UpdateRate
    self.Velocity = self.Velocity + Gravity

    self.TimeAtLastSimulation = UnPredictedCurTime()
    self.First = self.TickLifetime < 1
    self.TickLifetime = self.TickLifetime + 1
end

function ProjectileInfo:OnHit()
    if self.MoveTrace.HitSky then 
        self:Delete()
        return
    end

    local BulletInfo = self.BulletInfo

    if not self.Attacker or not self.Attacker:IsValid() then
        self:Delete()
        return
    end

    if self.ShouldFireBulletOnHit or true then
        self:FireBullet()

        if CLIENT then
            EmitSound("sonic_Crack.Distant", self.MoveTrace.HitPos, 0, CHAN_STATIC, 5, 160, 0, 150, 0)
        end
    end

    -- Delete the projectile
    self:Delete()
end

function ProjectileInfo:OnBounce()
    local SpeedLoss = 1--1 - (self.MoveTrace.HitNormal:Dot(-self.Forward))

    

    self.Velocity = Reflect(self.Velocity, self.MoveTrace.HitNormal) * SpeedLoss
    self.Bounced = true
    self.Cracked = false

    BounceEffect:SetOrigin(self.Position)
    BounceEffect:SetNormal(self.Forward)
    BounceEffect:SetMagnitude(1)
    BounceEffect:SetScale(1)
    util.Effect( "ElectricSpark", BounceEffect)

    -- Play bounce sound
    if CLIENT then
        EmitSound("sonic_Crack.Distant", self.MoveTrace.HitPos, 0, CHAN_STATIC, 5, 160, 0, 255, 0)
    end
end

if CLIENT then

    // Rendering

    local function ClientModel(Data)
        if Data.Entity and Data.Entity:isValid() then
            GhostEntity:SetModel(Data.Model)
            return GhostEntity
        end
        GhostEntity = ClientsideModel(Data.Model)
        GhostEntity:SetNoDraw(true)
        GhostEntity:SetPos(Data.Position)
        GhostEntity:SetAngles(Data.Angle)
        GhostEntity:SetRenderMode(RENDERMODE_TRANSALPHA)
        return GhostEntity
    end

    local BulletModel = ClientModel({
        Model = "models/hunter/misc/sphere025x025.mdl",
        Position = Vector(0, 0, 0),
        Angle = Angle(0, 0, 0)
    })
    BulletModel:SetMaterial("lights/white")

    local GlowEffect = Material("sprites/orangecore2")
    local Tracer = Material("effects/tracer_middle")
    local LightsWhite = Material("lights/white")
    local ScaleMatrix = Matrix()


    function ProjectileInfo:Render()
        local RenderTick = 1
        if self.TickLifetime > RenderTick and not self.Bounced then
            -- Main shape
            render.SetMaterial(GlowEffect)
            render.DrawBeam(self.InterpolatedPosition - self.Forward * 32, self.InterpolatedPosition + self.Forward * 32, 6, 0, 1)

            -- Bullet
            ScaleMatrix:SetScale(Vector(4, 0.1, 0.1))
            BulletModel:EnableMatrix("RenderMultiply", ScaleMatrix)
            BulletModel:SetPos(self.InterpolatedPosition)
            BulletModel:SetAngles(self.Forward:Angle())
            BulletModel:SetupBones()

            local BulletColor = LerpVector(0.85, Vector(1, 0.5, 0), Vector(1, 1, 1))
            render.SetColorModulation(BulletColor[1], BulletColor[2], BulletColor[3])
            BulletModel:DrawModel()
            render.SetColorModulation(1, 1, 1)

            -- Tracer
            render.SetMaterial(Tracer)
            if self.TickLifetime < (RenderTick - 1) then
                render.DrawBeam(self.InterpolatedPosition, self.LastPosition, 6, 0, 1)
            else
                render.DrawBeam(self.InterpolatedPosition, self.InterpolatedPosition - self.Forward * 256, 6, 0, 1)
            end
        end
    end

    // Sounds
    function ProjectileInfo:Crack()
        local Eyepos = EyePos()

        if self.Position:DistToSqr(Eyepos) > 1500^2 then return end
        if self.Cracked then return end


        local Start, End = self.LastPosition, self.Position
        local DistanceToLine, Point, Fraction = util.DistanceToLineFrac(Start, End, Eyepos)

        local Distances = {
            {100, "sonic_Crack.Light", 1},
            {400, "sonic_Crack.Heavy", 1 - ((DistanceToLine / 400) * 0.5)},
            {1200, "sonic_Crack.Medium", 1 - (DistanceToLine / 1200)}
        }
        if not self.First and Fraction < 1 then
            for i=1, #Distances do
                local TheFuck = Distances[i]
                if DistanceToLine < TheFuck[1] then
                    self.Cracked = true
                    local Volume = TheFuck[3]
                    local SoundPath = TheFuck[2]
                    EmitSound(SoundPath, Point, 0, CHAN_AUTO, Volume, 150, 0, 100, 0)
                    break
                end
            end
        end
    end
end

/////////////////////////////////////////////////////////////////////////////////////////////////////

local C_ProjectileManager = {}
C_ProjectileManager.__index = C_ProjectileManager
_G.C_ProjectileManager = C_ProjectileManager


-- Create a projectile manager
function C_ProjectileManager:New()
    local self = {}

    self.Projectiles = {}
    self.AttachedEntity = NULL 
    self.ShouldPredict = true
    self.Index = 0

    return setmetatable(self, C_ProjectileManager)
end

function C_ProjectileManager:EnablePrediction()
    self.ShouldPredict = true
end

function C_ProjectileManager:DisablePrediction()
    self.ShouldPredict = false
end

function C_ProjectileManager:GetPrediction()
    return self.ShouldPredict
end

function C_ProjectileManager:AttachToPlayer(Player)
    -- Sets the manager for the player, returns false if failed to assign manager
    local WasAssigned = Player:SetProjectileManager(self)

    -- Failed to assign manager
    if not WasAssigned then return end

    self.AttachedEntity = Player
end

-- Gets the entity the manager is attached to
function C_ProjectileManager:GetAttachedEntity()
    return self.AttachedEntity
end

-- Checks if the manager is attached to an entity
function C_ProjectileManager:IsAttachedToEntity()
    return self.AttachedEntity ~= nil and self.AttachedEntity ~= NULL
end

-- Gets projectiles from the list
function C_ProjectileManager:GetProjectiles()
    return self.Projectiles
end

-- Add projectile to the list
function C_ProjectileManager:AddProjectile(_ProjectileInfo)
    local Index = table.insert(self.Projectiles, _ProjectileInfo)
    _ProjectileInfo:SetManager(self, Index)
end

-- Removes projectile from the list
function C_ProjectileManager:RemoveProjectile(_ProjectileInfo)
    self.Projectiles[_ProjectileInfo.Index] = nil
end

function C_ProjectileManager:CreateProjectile(BulletInfo)
    -- Prevent prediction from the engine
    if self:GetPrediction() and not IsFirstTimePredicted() then return end

    -- Create a new projectile structure
    local Projectile = ProjectileInfo:New()

    -- Setup the projectile structure
    Projectile:Setup(BulletInfo)

    -- Get the entity which the manager is attached to
    local AttachedEntity = self:GetAttachedEntity()
    if AttachedEntity:IsPlayer() then
        -- Set attacker of the projectile in case it is not set
        --Projectile.BulletInfo.Attacker = AttachedEntity

        if self:GetPrediction() then
            -- Get the current command
            local CUserCmd = AttachedEntity:GetCurrentCommand()
            
            -- Set the tick at which the bullet was fired (allows for mostly accurate lag compensation)
            if CUserCmd then
                Projectile:SetTickCount(CUserCmd:TickCount())
            else
                Projectile:SetTickCount(engine.TickCount())
            end
        else
            -- Cannot use current command when not in a prediction so we use the server tick count
            Projectile:SetTickCount(engine.TickCount())
        end
    else 
        Projectile:SetTickCount(engine.TickCount())
    end

    -- Call the internal hook function
    self:OnCreateProjectile(Projectile.BulletInfo)

    -- Add projectile to the manager's projectile list
    self:AddProjectile(Projectile)
    return Projectile
end

function C_ProjectileManager:OnCreateProjectile(BulletInfo)
    -- Hi
end

if SERVER then
    function C_ProjectileManager:OnSetupMove(Player, CMoveData, CUserCmd)
        if not self:GetPrediction() then return end
        if not IsFirstTimePredicted() then return end

        C_LagCompensationManager:StartLagCompensation(Player)
        for _, Projectile in next, self:GetProjectiles() do
            
            local TargetTick = Projectile:GetTickCount() + Projectile:GetSimulationTick() - 1
            C_LagCompensationManager:BacktrackTo(TargetTick)
            Projectile:Simulate()
            
            C_HitboxSystem:QueryRaycast(Projectile.MoveTrace, function()
                Projectile:OnHit()
            end)
        end
        C_LagCompensationManager:EndLagCompensation()
    end
else
    function C_ProjectileManager:OnSetupMove(Player, CMoveData, CUserCmd)
        if not self:GetPrediction() then return end
        if not IsFirstTimePredicted() then return end
    
        for _, Projectile in next, self:GetProjectiles() do
            Projectile:Simulate()
            
            if Projectile.MoveTrace.Hit then
                Projectile:OnHit()
            end
        end

    end
end

function C_ProjectileManager:OnSetupMoveUnpredicted()
    if self:GetPrediction() then return end
    for _, Projectile in next, self:GetProjectiles() do
        Projectile:Simulate()

        if Projectile.MoveTrace.Hit then
            Projectile:OnHit()
        end
    end
end


if CLIENT then
    function C_ProjectileManager:InterpolateProjectilePositions()
        for _, Projectile in next, self:GetProjectiles() do
            Projectile:InterpolatePositions()
        end
    end

    function C_ProjectileManager:RenderProjectiles()
        for _, Projectile in next, self:GetProjectiles() do
            Projectile:Render()
        end
    end

    function C_ProjectileManager:CrackProjectiles()
        for _, Projectile in next, self:GetProjectiles() do
            Projectile:Crack()
        end
    end
end

/////////////////////////////////////////////////////////////////////////////////////////////////////

function PlayerMeta:GetProjectileManager()
    return self.ProjectileManager
end

function PlayerMeta:SetProjectileManager(Manager)
    -- Only allow one manager per player
    -- The manager was not assigned
    if self:GetProjectileManager() ~= nil then return false end
    
    self.ProjectileManager = Manager

    -- The manager was assigned
    return true 
end

function PlayerMeta:RemoveProjectileManager()
    self.ProjectileManager = nil
end
