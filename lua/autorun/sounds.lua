AddCSLuaFile()

sound.Add({
    name = "sonic_Crack.Light",
    channel = CHAN_STATIC,
    volume = 1.0,
    level = 80,
    sound = {
        "cracks/light/light_crack_01.ogg",
        "cracks/light/light_crack_02.ogg",
        "cracks/light/light_crack_03.ogg",
        "cracks/light/light_crack_04.ogg",
        "cracks/light/light_crack_05.ogg",
        "cracks/light/light_crack_06.ogg",
        "cracks/light/light_crack_06.ogg",
        "cracks/light/light_crack_07.ogg",
        "cracks/light/light_crack_08.ogg",
        "cracks/light/light_crack_09.ogg"
    }
})

sound.Add({
    name = "sonic_Crack.Medium",
    channel = CHAN_STATIC,
    volume = 1.0,
    level = 80,
    sound = {
        "cracks/medium/med_crack_01.ogg",
        "cracks/medium/med_crack_02.ogg",
        "cracks/medium/med_crack_03.ogg",
        "cracks/medium/med_crack_04.ogg",
        "cracks/medium/med_crack_05.ogg",
        "cracks/medium/med_crack_06.ogg",
        "cracks/medium/med_crack_06.ogg",
        "cracks/medium/med_crack_07.ogg",
        "cracks/medium/med_crack_08.ogg",
        "cracks/medium/med_crack_09.ogg"
    }
})

sound.Add({
    name = "sonic_Crack.Heavy",
    channel = CHAN_STATIC,
    volume = 1.0,
    level = 80,
    sound = {
        "cracks/heavy/heav_crack_01.ogg",
        "cracks/heavy/heav_crack_02.ogg",
        "cracks/heavy/heav_crack_03.ogg",
        "cracks/heavy/heav_crack_04.ogg",
        "cracks/heavy/heav_crack_05.ogg",
        "cracks/heavy/heav_crack_06.ogg",
        "cracks/heavy/heav_crack_06.ogg",
        "cracks/heavy/heav_crack_07.ogg",
        "cracks/heavy/heav_crack_08.ogg",
        "cracks/heavy/heav_crack_09.ogg"
    }
})

sound.Add({
    name = "sonic_Crack.Distant",
    channel = CHAN_STATIC,
    volume = 1.0,
    level = 150,
    pitch = {100, 0},
    sound = {
        "cracks/distant/dist_crack_01.ogg",
        "cracks/distant/dist_crack_02.ogg",
        "cracks/distant/dist_crack_03.ogg",
        "cracks/distant/dist_crack_04.ogg",
        "cracks/distant/dist_crack_05.ogg",
        "cracks/distant/dist_crack_06.ogg",
        "cracks/distant/dist_crack_06.ogg",
        "cracks/distant/dist_crack_07.ogg",
        "cracks/distant/dist_crack_08.ogg",
        "cracks/distant/dist_crack_09.ogg",
        "cracks/distant/dist_crack_10.ogg",
        "cracks/distant/dist_crack_11.ogg",
        "cracks/distant/dist_crack_12.ogg",
        "cracks/distant/dist_crack_13.ogg",
        "cracks/distant/dist_crack_14.ogg",
        "cracks/distant/dist_crack_15.ogg",
        "cracks/distant/dist_crack_16.ogg",
        "cracks/distant/dist_crack_17.ogg"
    }
})

-- Add ressources
if SERVER then
    // Distant
    local FilePaths = file.Find("sound/cracks/distant/*.ogg", "GAME", "nameasc")
    for _, FilePath in ipairs(FilePaths) do
        resource.AddSingleFile(FilePath)
    end

    // Heavy
    local FilePaths = file.Find("sound/cracks/heavy/*.ogg", "GAME", "nameasc")
    for _, FilePath in ipairs(FilePaths) do
        resource.AddSingleFile(FilePath)
    end

    // Medium
    local FilePaths = file.Find("sound/cracks/medium/*.ogg", "GAME", "nameasc")
    for _, FilePath in ipairs(FilePaths) do
        resource.AddSingleFile(FilePath)
    end

    // Light
    local FilePaths = file.Find("sound/cracks/light/*.ogg", "GAME", "nameasc")
    for _, FilePath in ipairs(FilePaths) do
        resource.AddSingleFile(FilePath)
    end
end