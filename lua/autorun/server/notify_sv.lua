if CLIENT then return end

octolib = octolib or {}
octolib.notify = octolib.notify or {}

util.AddNetworkString('octolib.notify.send')

function octolib.notify.send(ply, type, text)
    local data = {}
    data.type = type
    data.text = text
    
    net.Start('octolib.notify.send')
    net.WriteTable(data)
    net.Send(ply)
end

function octolib.notify.sendAll(type, text)
    local data = {}
    data.type = type
    data.text = text
    
    net.Start('octolib.notify.send')
    net.WriteTable(data)
    net.Broadcast()
end