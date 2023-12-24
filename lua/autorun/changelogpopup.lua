if SERVER then return end
local VersionNumber = 1

local Changelog = [[(1) Added settings menu,
    Command: (bulletphysics_menu)

(2) Fixed some impact particles not 
showing up.

(3) Fixed explosive props not exploding.]]


function markup.EZParse(text, color, optionalFont)
    if not color then color = Color(255, 255, 255) end
    if not optionalFont then optionalFont = "Title" end
    return markup.Parse("<font=" .. optionalFont .. "><color=" .. markup.Color(color) .. ">" .. text .. "</font></color>")
end

surface.CreateFont( "Title", {
    font = "Roboto", --  Use the font-name which is shown to you by your operating system Font Viewer, not the file name
    extended = false,
    size = 18,
    weight = 500,
    blursize = 0,
    scanlines = 1,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = true,
    additive = false,
    outline = false,
} )

surface.CreateFont( "Changelogs", {
    font = "Roboto", --  Use the font-name which is shown to you by your operating system Font Viewer, not the file name
    extended = false,
    size = 12,
    weight = 500,
    blursize = 0,
    scanlines = 0,
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
local function CreateChangelogMenu()
    local size = {256, 192}
    local ChangelogPopup = vgui.Create("DFrame")
    ChangelogPopup:SetTitle("")
    ChangelogPopup:SetSize(size[1], size[2])
    ChangelogPopup:Center()
    ChangelogPopup:SetDraggable(false)
    ChangelogPopup:MakePopup()
    ChangelogPopup:SetKeyboardInputEnabled(false)

    local UpdatedPanel = ChangelogPopup:Add("DLabel")
    UpdatedPanel:SetHeight(32)
    UpdatedPanel:SetText("")
    function UpdatedPanel:Paint(w, h)
        surface.SetDrawColor(Color(128, 128, 128))
        surface.DrawRect(0, 0, w, h)

        -- Text
        local Parsed = markup.EZParse("Bullet Physics Updated!", Color(255, 255, 255), "Title")

        Parsed:Draw(w * 0.5, h * 0.5, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 255, TEXT_ALIGN_CENTER)
    end
    UpdatedPanel:Dock(TOP)
    UpdatedPanel:DockMargin(0, 0, 0, 3)

    local ChangelogPanel = ChangelogPopup:Add("DLabel")
    ChangelogPanel:SetText("")
    function ChangelogPanel:Paint(w, h)
        surface.SetDrawColor(Color(36, 36, 36))
        surface.DrawRect(0, 0, w, h)

        -- Text
        local Parsed = markup.EZParse(Changelog, Color(192, 192, 192), "Changelogs")

        Parsed:Draw(8, 8, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 255, TEXT_ALIGN_LEFT)
    end
    ChangelogPanel:Dock(FILL)
end

timer.Simple(0, function()
    -- If it doesnt exist, create it and open popup
    if not file.Exists("bulletphysics/version.txt", "DATA") then
        file.Write("bulletphysics/version.txt", tostring(VersionNumber))

        CreateChangelogMenu()
    end

    if file.Exists("bulletphysics/version.txt", "DATA") then
        local String = file.Read("bulletphysics/version.txt", "DATA")
        local OldVersionNumber = tonumber(String)

        if VersionNumber ~= OldVersionNumber then
            file.Write("bulletphysics/version.txt", tostring(VersionNumber))
            CreateChangelogMenu()
        end
    end
end)