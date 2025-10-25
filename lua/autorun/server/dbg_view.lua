--[[

Мне лень целиком переносить в этот аддон netstream с дбг

]]--

util.AddNetworkString('dbg-view.setFov')
util.AddNetworkString('dbg-quickLook')

local pmeta = FindMetaTable('Player')
local setFov = pmeta.SetFOV

function pmeta:SetFOV(fov, time, requester)
	if setFov then setFov(self, fov, time, requester) end
	local data = {}
	data.fov = fov
	data.time = time or 0
	net.Start('dbg-view.setFov')
	net.WriteTable(data)
	net.Send(self)
end

net.Receive('dbg-quickLook', function(len, ply)
	if ply:IsFrozen() then return end

	local doFreeze = true

	if doFreeze then ply:Freeze(true) end

	timer.Simple(3.8, function()
		if not IsValid(ply) then return end
		if doFreeze then ply:Freeze(false) end
	end)

end)
