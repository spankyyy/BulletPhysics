AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Test Bullet Spawner"
ENT.Category = "Bullet Physics"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.Editable = true

DEFINE_BASECLASS(ENT.Base)

local UNIT = include("ballistica/core/unit.lua")

function ENT:SetupDataTables()

    local Types = {}
    for k,_ in pairs(Ballistica.ProjectileTypes) do
        Types[k] = k
    end



	self:NetworkVar("Bool", 0, "ShooterFireOnUse", {
        KeyName = "shooterfireuse", 
        Edit = {
            type = "Boolean", 
            order = 1,
            category = "Shooter",
        } 
    })

    self:NetworkVar("Float", 0, "ShooterFirerate", {
        KeyName = "shooterfirerate", 
        Edit = {
            type = "Int", 
            order = 2,
            category = "Shooter",
            min = 1,
            max = 66
        } 
    })

	self:NetworkVar("String", 0, "ProjectileName", {
        KeyName = "projectileclass", 
        Edit = {
            type = "Combo", 
            order = 10,
            category = "Projectile",
            text = "default_bullet",
            values = Types
        } 
    })

	self:NetworkVar("Float", 1, "ProjectilePerShot", {
        KeyName = "projectileshot", 
        Edit = {
            type = "Int", 
            order = 11,
            category = "Projectile",
            min = 1,
            max = 16
        } 
    })

	self:NetworkVar("Float", 2, "ProjectileDamage", {
        KeyName = "projectiledamage", 
        Edit = {
            type = "Int", 
            order = 12,
            category = "Projectile",
            min = 0,
            max = 100
        } 
    })

    self:NetworkVar("Float", 3, "ProjectileSpread", {
        KeyName = "projectilespread", 
        Edit = {
            type = "Float", 
            order = 13,
            category = "Projectile",
            min = 0,
            max = 1
        } 
    })

    self:NetworkVar("Float", 4, "ProjectileSpeed", {
        KeyName = "projectilespeed", 
        Edit = {
            type = "Float", 
            order = 14,
            category = "Projectile",
            min = 0,
            max = 3000
        } 
    })

    if SERVER then
        self:SetShooterFireOnUse(false)
        self:SetShooterFirerate(1)

        self:SetProjectileName("default_bullet")
        self:SetProjectilePerShot(1)
        self:SetProjectileDamage(0)
        self:SetProjectileSpread(0)
        self:SetProjectileSpeed(2000)
    end

end


if SERVER then
    function ENT:Initialize()
        BaseClass.Initialize(self)
        self:SetModel("models/maxofs2d/cube_tool.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:GetPhysicsObject():Wake()
        self:SetUseType(SIMPLE_USE)
        self:SetBodygroup(2, 1)
    end

    function ENT:Shoot()
        local bulletInfo = {
            Class = self:GetProjectileName(),
            Src = self:GetPos() - self:GetForward() * 9,
            Dir = -self:GetForward(),
            Num = self:GetProjectilePerShot(),
            Damage = self:GetProjectileDamage(),
            Spread = Vector(self:GetProjectileSpread(), 0, 0),
            Speed = UNIT.FT_TO_HAMMER(self:GetProjectileSpeed())
        }
        --self:CreateProjectile(bulletInfo, "default_bullet")
        self:FireBullets(bulletInfo)
    end

    function ENT:Use(Activator)
        if not self:GetShooterFireOnUse() then return end

        self:Shoot()
    end

    function ENT:Think()
        if self:GetShooterFireOnUse() then return end
        
        self:NextThink(CurTime() + (1 / self:GetShooterFirerate()))

        self:Shoot()
        
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
