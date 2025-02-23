AddCSLuaFile()

local UNIT = {}

function UNIT.CM_TO_HAMMER(Unit)
    return Unit / 1.905
end
function UNIT.HAMMER_TO_CM(Unit)
    return Unit * 1.905
end

function UNIT.M_TO_HAMMER(Unit)
    return Unit / 0.01905
end
function UNIT.HAMMER_TO_M(Unit)
    return Unit * 0.01905
end

function UNIT.FT_TO_CM(Unit)
    return Unit * 30.48
end
function UNIT.CM_TO_FT(Unit)
    return Unit / 30.48
end

function UNIT.FT_TO_HAMMER(Unit)
    return Unit * 16
end
function UNIT.HAMMER_TO_FT(Unit)
    return Unit / 16
end

return UNIT
