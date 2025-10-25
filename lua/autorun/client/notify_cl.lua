if SERVER then return end

octolib = octolib or {}
octolib.notify = octolib.notify or {}

octolib.notifyColors = {
	rp = Color(255, 220, 100),
	warning = Color(214, 74, 65),
	ooc = Color(43, 123, 167),
	hint = Color(16, 140, 73),
}

function octolib.notify.show(type, text)
	surface.PlaySound('buttons/lightswitch2.wav') 
	local color = octolib.notifyColors[type]
	chat.AddText(color, '[#] ' , Color(250, 250, 200), text)
end

net.Receive('octolib.notify.send', function()
    local data = net.ReadTable()
    octolib.notify.show(data.type, data.text)
end)