local BulletPhysicsSettings = {}
BulletPhysicsSettings.__index = BulletPhysicsSettings
_G.BulletPhysicsSettings = BulletPhysicsSettings

BulletPhysicsSettings.Settings = {}

local DefaultSettings = {
    Projectiles = {
        DefaultSpeed = 20000,
        Gravity = 1000,
        EnableSounds = true,
        ShouldBounce = true,
    },
    DetouredWeapons = {
        weapon_pistol = true,
        weapon_357 = true,
        weapon_smg1 = true,
        weapon_ar2 = true,
        weapon_shotgun = true
    }
}

local DetouredWeaponBlacklist = {
    gmod_tool = true,
    gmod_camera = true,
    none = true
}

if SERVER then
    util.AddNetworkString("NetworkBulletPhysicsSettings")

    local function CheckFile()
        -- Create the settings file if it doesnt exist
        if not file.Exists("bulletphysics", "DATA") then
            file.CreateDir("bulletphysics")

            local DefaultSettings = table.Copy(DefaultSettings)

            -- Add sweps to detoured weapons
            for k, Weapon in next, weapons.GetList() do
                local StoredWeapon = weapons.Get(Weapon.ClassName)
                local IsBase = (StoredWeapon == nil) and false or (StoredWeapon.Base == "weapon_base")
                if not IsBase and not DetouredWeaponBlacklist[Weapon.ClassName] then
                    DefaultSettings.DetouredWeapons[Weapon.ClassName] = DefaultSettings.DetouredWeapons[Weapon.ClassName] or true 
                end
            end

            -- Write file
            local Settings = util.TableToJSON(DefaultSettings, true)
            file.Write("bulletphysics/settings.json", Settings)

            print("Bullet Physics: Created directory and settings file")
        elseif not file.Exists("bulletphysics/settings.json", "DATA") then
            local DefaultSettings = table.Copy(DefaultSettings)

            -- Add sweps to detoured weapons
            for k, Weapon in next, weapons.GetList() do
                local StoredWeapon = weapons.Get(Weapon.ClassName)
                local IsBase = (StoredWeapon == nil) and false or (StoredWeapon.Base == "weapon_base")
                if not IsBase and not DetouredWeaponBlacklist[Weapon.ClassName] then
                    DefaultSettings.DetouredWeapons[Weapon.ClassName] = DefaultSettings.DetouredWeapons[Weapon.ClassName] or true 
                end
            end

            -- Write file
            local Settings = util.TableToJSON(DefaultSettings, true)
            file.Write("bulletphysics/settings.json", Settings)

            print("Bullet Physics: Created settings file")
        end
    end
    CheckFile()

    -- Get settings
    function BulletPhysicsSettings:GetSettings()
        CheckFile()

        local Settings = file.Read("bulletphysics/settings.json", "DATA")
        Settings = util.JSONToTable(Settings, true, true)
        self.Settings = Settings
        return Settings
    end

    -- Update settings
    function BulletPhysicsSettings:UpdateSettings(Settings)
        CheckFile()

        if not Settings then 
            Settings = self:GetSettings()
        end

        -- If it so happens that theres new settings, add them
        for k, v in next, DefaultSettings.Projectiles do
            Settings.Projectiles[k] = (Settings.Projectiles[k] == nil) and v or Settings.Projectiles[k]
        end
        
        -- Add sweps to detoured weapons
        for k, Weapon in next, weapons.GetList() do
            local StoredWeapon = weapons.Get(Weapon.ClassName)
            local IsBase = (StoredWeapon == nil) and false or (StoredWeapon.Base == "weapon_base")
            if not IsBase and not DetouredWeaponBlacklist[Weapon.ClassName] then
                DefaultSettings.DetouredWeapons[Weapon.ClassName] = DefaultSettings.DetouredWeapons[Weapon.ClassName] or true 
            end
        end

        self.Settings = Settings

        -- Write file
        local Settings = util.TableToJSON(Settings, true)
        file.Write("bulletphysics/settings.json", Settings)

        print("Bullet Physics: Updated settings")
    end
end

if CLIENT then
    -- Get settings
    function BulletPhysicsSettings:GetSettings()
        return self.Settings
    end

    function BulletPhysicsSettings:GetDefaultSettings()
        local DefaultSettings = table.Copy(DefaultSettings)

        -- Add sweps to detoured weapons
        for k, Weapon in next, weapons.GetList() do
            local StoredWeapon = weapons.Get(Weapon.ClassName)
            local IsBase = (StoredWeapon == nil) and false or (StoredWeapon.Base == "weapon_base")
            if not IsBase and not DetouredWeaponBlacklist[Weapon.ClassName] then
                DefaultSettings.DetouredWeapons[Weapon.ClassName] = DefaultSettings.DetouredWeapons[Weapon.ClassName] or true 
            end
        end
        return DefaultSettings
    end
end
