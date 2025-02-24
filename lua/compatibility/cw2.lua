AddCSLuaFile()

local Base = weapons.GetStored("cw_base")

if not IsValid(Base) then return end

local bul = {}
function Base:FireBullet(damage, cone, clumpSpread, bullets)
	sp = self.Owner:EyePos()
	local commandNumber = self.Owner:GetCurrentCommand():CommandNumber()
	math.randomseed(commandNumber)
	
	if self.Owner:Crouching() then
		cone = cone * 0.85
	end
	
	Dir = (self.Owner:EyeAngles() + self.Owner:GetViewPunchAngles() + Angle(math.Rand(-cone, cone), math.Rand(-cone, cone), 0) * 25):Forward()
	clumpSpread = clumpSpread or self.ClumpSpread
	
	CustomizableWeaponry.callbacks.processCategory(self, "adjustBulletStructure", bul)
	
	for i = 1, bullets do
		Dir2 = Dir
		
		if clumpSpread and clumpSpread > 0 then
			Dir2 = Dir + Vector(math.Rand(-1, 1), math.Rand(-1, 1), math.Rand(-1, 1)) * clumpSpread
		end
		
		if not CustomizableWeaponry.callbacks.processCategory(self, "suppressDefaultBullet", sp, Dir2, commandNumber) then
			bul.Num = 1
			bul.Src = sp
			bul.Dir = Dir2
			bul.Spread 	= zeroVec --Vector(0, 0, 0)
			bul.Tracer	= 3
			bul.Force	= damage * 0.3
			bul.Damage = math.Round(damage)
			bul.Callback = self.bulletCallback
			bul.wep = self
			
			self.Owner:FireBullets(bul)
		end
	end
end