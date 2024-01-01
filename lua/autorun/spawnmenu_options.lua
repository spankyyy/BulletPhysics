AddCSLuaFile()

local HookIndentifier = "BPhys_"

local function MySlider(Parent, Name, ID, Min, Max, Decimals)
    local Slider = Parent:NumSlider(Name, ID, Min, Max, Decimals)
    local Text = Slider:GetTextArea()
    Text:SetUpdateOnType(false)
    Text.OnTextChanged = function() end
    return Slider
end


hook.Add("AddToolMenuCategories", HookIndentifier .. "SpawnmenuOptionsCategory", function()
	spawnmenu.AddToolCategory("Options", "bulletphysics_options", "Bullet Physics")
end)

hook.Add("PopulateToolMenu", HookIndentifier .. "SpawnmenuOptions", function()
    spawnmenu.AddToolMenuOption("Options", "bulletphysics_options", "bulletphysics_general", "General", "", "", function(Panel)
        Panel:ClearControls()

        // Divider
		local divider = vgui.Create("DPanel")
		divider:SetTall(4)
		Panel:AddItem(divider)
        //////////////////////////////////////////////////////

        Panel:CheckBox("Enable BulletPhysics", "bulletphysics_enabled")
        Panel:ControlHelp("Master killswitch.")

        // Divider
		local divider = vgui.Create("DPanel")
		divider:SetTall(4)
		Panel:AddItem(divider)
        //////////////////////////////////////////////////////

        MySlider(Panel, "Default Gravity", "bulletphysics_gravity", 0, 10000, 0)
        Panel:ControlHelp("Sets the default gravity of the bullets.")

        MySlider(Panel, "Default Speed", "bulletphysics_defaultspeed", 10000, 1000000, 0)
        Panel:ControlHelp("Sets the default speed of the bullets.")

        // Divider
		local divider = vgui.Create("DPanel")
		divider:SetTall(4)
		Panel:AddItem(divider)
        //////////////////////////////////////////////////////

        Panel:CheckBox("Enable Sounds", "bulletphysics_enablesounds")
        Panel:ControlHelp("Enable sound effects.")

        Panel:CheckBox("Enable Ricochet", "bulletphysics_enablebounce")
        Panel:ControlHelp("Enable projectile ricochet.")

        Panel:CheckBox("Enable Penetration", "bulletphysics_enablepenetration")
        Panel:ControlHelp("Coming soon.")

        // Divider
		local divider = vgui.Create("DPanel")
		divider:SetTall(4)
		Panel:AddItem(divider)
        //////////////////////////////////////////////////////

        Panel:Button("Open detour menu.", "")
        Panel:ControlHelp("Coming soon.")
    end)
end)