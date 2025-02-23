AddCSLuaFile()


-- Remove internal physics bullets from every gun that can have it
-- Dont do it actually since it breaks attachments/guns that access the table


for k,v in pairs(weapons.GetList()) do
	if string.StartsWith(v.ClassName, "mg") then
		local Base = weapons.GetStored(v.ClassName)


        --Base.Projectile = nil
	end
end