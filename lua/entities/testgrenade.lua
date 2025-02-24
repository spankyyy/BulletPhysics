AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Test Grenade"
ENT.Category = "Bullet Physics"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.Editable = true

DEFINE_BASECLASS(ENT.Base)

local UNIT = include("ballistica/core/unit.lua")
local Explosion = EffectData()


function ENT:SetupDataTables()

    local Types = {}
    for k,_ in pairs(Ballistica.ProjectileTypes) do
        Types[k] = k
    end

    self:NetworkVar("Float", 0, "ProjectilesPerExplosion", {
        KeyName = "projectilespergrenade", 
        Edit = {
            type = "Float", 
            order = 14,
            category = "Projectile",
            min = 0,
            max = 512
        } 
    })


    if SERVER then
        self:SetProjectilesPerExplosion(256)
    end

end


if SERVER then
    function ENT:Initialize()
        BaseClass.Initialize(self)
        self.Ignited = false
        self:SetModel("models/weapons/w_grenade.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:GetPhysicsObject():Wake()
        self:SetUseType(SIMPLE_USE)
    end

    function ENT:Explode()
        self.Ignited = false

        for i=1, self:GetProjectilesPerExplosion() do
            local RandomDirection = VectorRand(-100, 100):GetNormalized()

            local bulletInfo = {
                Class = "shrapnel",
                Src = self:GetPos(),
                Dir = RandomDirection,
                Num = 1,
                Damage = 100,
                Spread = Vector(0, 0),
                Speed = UNIT.FT_TO_HAMMER(600)
            }

            self:FireBullets(bulletInfo)

        end
        Explosion:SetOrigin(self:GetPos())
        Explosion:SetMagnitude(0)
        Explosion:SetScale(0)

        util.Effect("Explosion", Explosion)
        
        timer.Simple(0.01, function() self:Remove() end)
    end

    function ENT:Use(Activator)
        if self.Ignited then return end

        self.Ignited = true 

        self:SetModel("models/weapons/w_npcnade.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        --self:GetPhysicsObject():Wake()
        self:SetUseType(SIMPLE_USE)
        self:SetPos(self:GetPos() + self:GetUp() * 4)

        timer.Simple(3, function()
            self:Explode()
        end)
    end

    function ENT:Think()
        self:NextThink(CurTime())
        return true
    end
end

if CLIENT then
    function ENT:Initialize()

    end


    function ENT:Think()
        self:NextThink(CurTime())
        return true
    end

    function ENT:Draw()
        render.SuppressEngineLighting(true)
        self:DrawModel()
        render.SuppressEngineLighting(false)
    end
end
