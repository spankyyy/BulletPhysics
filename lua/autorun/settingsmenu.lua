if CLIENT then
    concommand.Add("bulletphysics_menu", function()
        if not LocalPlayer():IsSuperAdmin() then
            print("You don't have the permissions to use this command")
            return
        end
        
        local Settings = BulletPhysics.Settings--table.IsEmpty(BulletPhysics.Settings) and BulletPhysicsSettings:GetDefaultSettings() or BulletPhysics.Settings
        local SettingsCopy = table.Copy(Settings)


        local size = {512, 512 + 128}
        local SettingsPanel = vgui.Create("DFrame")
        SettingsPanel:SetSize(size[1], size[2])
        SettingsPanel:Center()
        SettingsPanel:SetTitle("Bullet Physics Settings")
        SettingsPanel:SetDraggable(false)
        SettingsPanel:MakePopup()
        SettingsPanel:SetKeyboardInputEnabled(false)

        local ApplySettings = SettingsPanel:Add("DButton")
        ApplySettings:SetHeight(64)
        ApplySettings:SetText("Apply Settings")
        ApplySettings:Dock(BOTTOM)

        local tabs = SettingsPanel:Add("DPropertySheet")
        tabs:Dock(FILL)

        local ProjectileSettingsPanel = vgui.Create("DPanel")
        local ProjectileSettings = ProjectileSettingsPanel:Add("DProperties")
        ProjectileSettings:Dock(FILL)

        for Name, Val in next, Settings.Projectiles do
            local Row = ProjectileSettings:CreateRow("Projectiles", Name)
            if type(Val) == "number" then
                Row:Setup("Int", {min = 0, max = 100000})
                Row:SetValue(Val)
                Row.DataChanged = function(_, Val)
                    SettingsCopy.Projectiles[Name] = math.Round(Val)
                end
            end
            if type(Val) == "boolean" then
                Row:Setup("Boolean")
                Row:SetValue(Val)
                Row.DataChanged = function(_, Val)
                    Val = (Val == 1)
                    SettingsCopy.Projectiles[Name] = Val
                end
            end
        end


        local WeaponDetoursPanel = vgui.Create("DPanel")
        local WeaponDetours = WeaponDetoursPanel:Add("DProperties")
        WeaponDetours:Dock(FILL)

        for WeaponName, Val in next, Settings.DetouredWeapons do
            local StoredWeapon = weapons.Get(WeaponName)

            local PrintName = WeaponName
            if StoredWeapon and StoredWeapon.PrintName ~= "" then
                PrintName = StoredWeapon.PrintName
            end

            local Row = WeaponDetours:CreateRow("Weapon Detours", PrintName)
            Row:Setup("Boolean")
            Row:SetValue(Val)
            Row.DataChanged = function(_, Val)
                Val = (Val == 1)
                SettingsCopy.DetouredWeapons[WeaponName] = Val
            end
        end


        tabs:AddSheet("Projectiles", ProjectileSettingsPanel, "icon16/wrench_orange.png", false, false, "tab1")
        tabs:AddSheet("Weapons", WeaponDetoursPanel, "icon16/gun.png", false, false, "tab1")

        function ApplySettings:DoClick()
            net.Start("NetworkBulletPhysicsSettings")
                net.WriteTable(SettingsCopy)
            net.SendToServer()
        end
    end)
end

if SERVER then


    net.Receive("NetworkBulletPhysicsSettings", function()
        local Settings = net.ReadTable()

        BulletPhysicsSettings:UpdateSettings(Settings)
        BulletPhysics.Settings = Settings

        net.Start("NetworkBulletPhysicsSettings")
            net.WriteTable(Settings)
        net.Broadcast()
    end)
end