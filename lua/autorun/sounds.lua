AddCSLuaFile()

sound.Add({
    name = "sonic_Crack.Light",
    channel = CHAN_STATIC,
    volume = 1.0,
    level = 80,
    pitch = {90, 110},
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
    pitch = {90, 110},
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
    pitch = {90, 110},
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


sound.Add({
    name = "sonic_Crack.Subsonic",
    channel = CHAN_STATIC,
    volume = 1.0,
    level = 150,
    pitch = {100, 100},
    sound = {
        "cracks/subsonic/subsonic01.wav",
        "cracks/subsonic/subsonic02.wav",
        "cracks/subsonic/subsonic03.wav",
        "cracks/subsonic/subsonic04.wav",
        "cracks/subsonic/subsonic05.wav",
        "cracks/subsonic/subsonic06.wav",
        "cracks/subsonic/subsonic07.wav",
        "cracks/subsonic/subsonic08.wav"
    }
})

sound.Add({
    name = "sonic_Crack.Supersonic",
    channel = CHAN_STATIC,
    volume = 1.0,
    level = 150,
    pitch = {100, 100},
    sound = {
        "cracks/supersonic/supersonic02.wav",
        "cracks/supersonic/supersonic03.wav",
        "cracks/supersonic/supersonic04.wav"
    }
})

sound.Add({
    name = "sonic_Crack.Ricochet",
    channel = CHAN_STATIC,
    volume = 1.0,
    level = 70,
    pitch = {100, 100},
    sound = {
        "ricochets/ric1.ogg",
        "ricochets/ric2.ogg",
        "ricochets/ric3.ogg",
        "ricochets/ric4.ogg",
        "ricochets/ric5.ogg"
    }
})


-- Add ressources
if SERVER then
    // Distant
    local FolderPath = "sound/cracks/distant/"
    local FilePaths = file.Find(FolderPath .. "*.ogg", "GAME", "nameasc")
    for _, FilePath in ipairs(FilePaths) do
        resource.AddSingleFile(FolderPath .. FilePath)
    end

    // Heavy
    local FolderPath = "sound/cracks/heavy/"
    local FilePaths = file.Find(FolderPath .. "*.ogg", "GAME", "nameasc")
    for _, FilePath in ipairs(FilePaths) do
        resource.AddSingleFile(FolderPath .. FilePath)
    end

    // Medium
    local FolderPath = "sound/cracks/medium/"
    local FilePaths = file.Find(FolderPath .. "*.ogg", "GAME", "nameasc")
    for _, FilePath in ipairs(FilePaths) do
        resource.AddSingleFile(FolderPath .. FilePath)
    end

    // Light
    local FolderPath = "sound/cracks/light/"
    local FilePaths = file.Find(FolderPath .. "*.ogg", "GAME", "nameasc")
    for _, FilePath in ipairs(FilePaths) do
        resource.AddSingleFile(FolderPath .. FilePath)
    end


    // Subsonic
    local FolderPath = "sound/cracks/subsonic/"
    local FilePaths = file.Find(FolderPath .. "*.wav", "GAME", "nameasc")
    for _, FilePath in ipairs(FilePaths) do
        resource.AddSingleFile(FolderPath .. FilePath)
    end

    // Supersonic
    local FolderPath = "sound/cracks/supersonic/"
    local FilePaths = file.Find(FolderPath .. "*.wav", "GAME", "nameasc")
    for _, FilePath in ipairs(FilePaths) do
        resource.AddSingleFile(FolderPath .. FilePath)
    end


    // Ricochet
    local FolderPath = "sound/ricochets/"
    local FilePaths = file.Find(FolderPath .. "*.ogg", "GAME", "nameasc")
    for _, FilePath in ipairs(FilePaths) do
        resource.AddSingleFile(FolderPath .. FilePath)
    end
end