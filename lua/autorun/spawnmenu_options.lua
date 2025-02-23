AddCSLuaFile()

local function MySlider(Parent, Name, ID, Min, Max, Decimals)
    local Slider = Parent:NumSlider(Name, ID, Min, Max, Decimals)
    local Text = Slider:GetTextArea()
    Text:SetUpdateOnType(false)
    Text.OnTextChanged = function() end
    return Slider
end

local function MyComboBox(Parent, Title, ID)
    local ComboBox, Label = Parent:ComboBox(Title, ID)
    return ComboBox, Label
end


hook.Add("AddToolMenuCategories", "BulletPhysics_SpawnmenuOptionsCategory", function()
	spawnmenu.AddToolCategory("Options", "bulletphysics_options", "Bullet Physics")
end)

hook.Add("PopulateToolMenu", "BulletPhysics_SpawnmenuOptions", function()
    spawnmenu.AddToolMenuOption("Options", "bulletphysics_options", "bulletphysics_general", "General", "", "", function(Panel)
        Panel:ClearControls()

        // Divider
		local divider = vgui.Create("DPanel")
		divider:SetTall(4)
		Panel:AddItem(divider)
        //////////////////////////////////////////////////////

        Panel:CheckBox("Enable BulletPhysics", "bulletphysics_enabled")
        Panel:ControlHelp("Master killswitch.")

        Panel:CheckBox("Enable Debug Info", "ballistica_debug")
        Panel:ControlHelp("Master killswitch.")

        // Divider
		local divider = vgui.Create("DPanel")
		divider:SetTall(4)
		Panel:AddItem(divider)
        //////////////////////////////////////////////////////

        local Box = MyComboBox(Panel, "Default Projectile", "bulletphysics_projectilename")
        for k, _ in pairs(Ballistica.ProjectileTypes) do
            Box:AddChoice(k)
        end
        Panel:ControlHelp("Sets the default projectile to use.")

        // Divider
		local divider = vgui.Create("DPanel")
		divider:SetTall(4)
		Panel:AddItem(divider)
        //////////////////////////////////////////////////////

        Panel:Button("Open detour menu.", "")
        Panel:ControlHelp("Coming soon.")

        // Divider
		local divider = vgui.Create("DPanel")
		divider:SetTall(4)
		Panel:AddItem(divider)
        //////////////////////////////////////////////////////

        Panel:Help("Current Issues:")
        Panel:Help("> None!")

        local issues = vgui.Create("DButton")
        issues:SetText("Got an issue or bug? Report it here!")
        issues:SetTall(64)

        function issues.DoClick() 
            gui.OpenURL("https://github.com/spankyyy/BulletPhysics/issues")
        end

		Panel:AddItem(issues)
    end)
end)