AddCSLuaFile()

local net = net

function net.WriteVectorFloat(Vec)
    net.WriteFloat(Vec[1])
    net.WriteFloat(Vec[2])
    net.WriteFloat(Vec[3])
end

function net.ReadVectorFloat()
    return Vector(net.ReadFloat(), net.ReadFloat(), net.ReadFloat())
end


if SERVER then
    function net.OmitBroad(Client)
        if Client and Client:IsValid() and Client:IsPlayer() and not game.SinglePlayer() then
            net.SendOmit(Client)
            return
        end
        net.Broadcast()
    end
end

return net