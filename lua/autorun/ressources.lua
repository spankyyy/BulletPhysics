if CLIENT then return end

local FolderPath = "materials/bulletphysics/"
local FilePaths = file.Find(FolderPath .. "*", "GAME", "nameasc")
for _, FilePath in ipairs(FilePaths) do
    print("Bullet Physics - Added Ressource: " .. FolderPath .. FilePath)
    resource.AddSingleFile(FolderPath .. FilePath)
end