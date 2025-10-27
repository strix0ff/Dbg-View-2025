octolib = octolib or {}
octolib.delay = octolib.delay or {}

dbgView = dbgView or {}
dbgView.mods = dbgView.mods or {}
dbgView.useSights = true

dbgView.disabledWeps = {
	gmod_camera = true,
	gmod_tool = true,
	weapon_physgun = true,
	dbg_admingun = true,
	octo_camera = true,
}

hook.Add('dbg-view.override', 'dbg-view.disabledWeapons', function()
	local wep = LocalPlayer():GetActiveWeapon()
	if IsValid(wep) and dbgView.disabledWeps[wep:GetClass()] then
		return false
	end
end)


function dbgView.hideHead(doHide)

	local ply = LocalPlayer()
	if not IsValid(ply) then return end

	local hat = ply:LookupBone('ValveBiped.Bip01_Head1') or 6
	ply:ManipulateBoneScale(hat, doHide and Vector(0.01, 0.01, 0.01) or Vector(1, 1, 1))
	dbgView.headHidden = doHide

end

function dbgView.flyTo(pos, ang, time)

	time = time or 1
	ease = ease or -1

	dbgView.startPos = dbgView.lastPos
	dbgView.startAng = dbgView.lastAng
	dbgView.tgtPos = pos
	dbgView.tgtAng = ang
	dbgView.flyStart = CurTime()
	dbgView.flyEnd = CurTime() + time
	dbgView.animActive = pos ~= nil

end

function dbgView.calcView(ply, pos, ang, fov)
	local func = hook.GetTable().CalcView['dbg-view']
	if not (func and dbgView.active) then return { origin = pos, angles = ang, fov = fov } end
	return func(ply, pos, ang, fov) or { origin = pos, angles = ang, fov = fov }
end

function dbgView.calcWeaponView(ply, pos, ang, fov)
	local wep = ply:GetActiveWeapon()
	if IsValid(wep) and wep.CalcView then
		local view = wep:CalcView(ply, pos, ang, fov)
		if not view then return end

		dbgView.viewpos = view.origin
		return view
	end
end

function dbgView.fovMod(delta, time)

	dbgView.startFov = dbgView.fov
	dbgView.tgtFov = (GetConVar('fov_desired'):GetFloat() or 90) + (delta or 0)
	dbgView.fovStart = CurTime()
	dbgView.fovEnd = CurTime() + time

end

function dbgView.lookMod(enabled, position, angles, radius)

	dbgView.lookActive = tobool(enabled) or nil
	if not dbgView.lookActive then
		dbgView.lookPosition = nil
		dbgView.lookAngles = nil
		dbgView.lookRadius = nil
		return
	end

	angles:Normalize()

	dbgView.lookPosition = position
	dbgView.lookRadius = radius
	dbgView.lookAngles = angles

end

function dbgView.setFov(fov, time)
	if fov ~= 0 then
		fov = fov - (GetConVar('fov_desired'):GetFloat() or 90)
	end
	dbgView.fovMod(fov, time)
end

net.Receive('dbg-view.setFov', function()
	local data = net.ReadTable()
	dbgView.setFov(data.fov, data.time)
end)

local pmeta = FindMetaTable('Player')
local setFov = pmeta.setFOV
function pmeta:SetFOV(fov, time, requester)
	if setFov then setFov(self, fov, time, requester) end
	dbgView.setFov(fov, time or 0)
end

local ply, anc, prevang, lookOffActive, blind = NULL, NULL, Angle(), false, false
local chPosOff, chAngOff, chDefault = Vector(0,0,0), Angle(0,90,90), Material('octoteam/icons/percent0.png')
local sens, lastModel, lastVeh = GetConVar('sensitivity'):GetFloat(), '', NULL
local traceMaxs, traceMins = Vector(5, 5, 3), Vector(-5, -5, -3)
local angle_zero = Angle()
local function filterList(ent)
	return not (ent == ply or ent:GetRenderMode() == RENDERMODE_TRANSALPHA or ent:GetClass() == 'prop_ragdoll')
end

local function recreateAnchor()

	if IsValid(anc) then anc:Remove() end
	anc = octolib.createDummy('models/props_junk/popcan01a.mdl')
	anc:SetParent(ply, 1)
	anc:SetLocalPos(Vector())
	anc:SetLocalAngles(Angle())
	anc:SetNoDraw(true)
	anc:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)

end

local function inputMouseApply(cmd, x, y, ang)

	if lookOffActive or dbgView.lookActive then
		if lookOffActive then
			dbgView.lookOff.p = math.Clamp(dbgView.lookOff.p + y * sens / 200, -45, 45)
			dbgView.lookOff.y = math.Clamp(dbgView.lookOff.y - x * sens / 200, -60, 60)
		end

		if dbgView.lookActive then
			dbgView.lookAngles = dbgView.lookAngles + Angle(y, -x, 0) * sens / 200
			dbgView.lookAngles.pitch = math.Clamp(dbgView.lookAngles.pitch, -65, 90)
		end

		cmd:SetMouseX(0)
		cmd:SetMouseY(0)
		return true
	elseif dbgView.lookOff.p ~= 0 or dbgView.lookOff.y ~= 0 then
		dbgView.lookOff.p = math.Approach(dbgView.lookOff.p, 0, math.max(math.abs(dbgView.lookOff.p), 0.2) * FrameTime() * 10)
		dbgView.lookOff.y = math.Approach(dbgView.lookOff.y, 0, math.max(math.abs(dbgView.lookOff.y), 0.2) * FrameTime() * 10)
	end

end

local function think()
	blind = false

	local veh = ply:GetVehicle()
	if ply:GetViewEntity() == ply and not IsValid(veh) and ply:GetMoveType() ~= MOVETYPE_NOCLIP then
		blind = util.TraceHull({
			maxs = traceMaxs,
			mins = traceMins,
			start = dbgView.viewpos,
			endpos = dbgView.viewpos,
			filter = filterList,
		}).Hit or util.TraceLine({
			start = ply:GetBonePosition(ply:LookupBone('ValveBiped.Bip01_Pelvis') or 0),
			endpos = dbgView.viewpos,
			filter = filterList
		}).Hit
	end
end

local function calcView(ply, pos, angles, fov)

	local mods = {
		origin = Vector(0,0,0),
		angles = Angle(),
		fov = 1,
		znear = 0,
		headScale = 0.01,
	}

	if ply:GetViewEntity() == ply and ply:Alive() and IsValid(anc) then
		ply.viewAngs = Angle(angles.p, angles.y, angles.r)

		local model = ply:GetModel()
		if model ~= lastModel then
			for i = 0, ply:GetBoneCount() - 1 do
				ply:ManipulateBoneScale(i, Vector(1,1,1))
			end
			dbgView.hideHead(true)
			recreateAnchor()

			lastModel = model
		end

		local veh = ply:GetVehicle()
		if veh ~= lastVeh then
			recreateAnchor()
			lastVeh = veh
		end

		if not IsValid(anc) or anc:GetParent() ~= ply then
			recreateAnchor()
		end

		local view = {
			fov = dbgView.fov,
			znear = 3,
		}

		local ancp, anca = anc:GetPos(), anc:GetAngles()
		angles = angles + dbgView.lookOff
		angles.p = math.Clamp(angles.p, -75, 75)
		view.angles = angles
		view.origin = ancp
		dbgView.viewpos = view.origin

		if debugViewForwardDist then
			view.origin:Add(angles:Forward() * debugViewForwardDist)
		end

		dbgView.calcPos = view.origin
		dbgView.calcAng = view.angles

		if dbgView.flyStart then
			local st = math.Clamp(math.TimeFraction(dbgView.flyStart, dbgView.flyEnd, CurTime()), 0, 1)
			local frac = octolib.tween.easing.inOutQuad(st, 0, 1, 1)
			if frac > 0 then
				view.origin = LerpVector(frac, dbgView.startPos, dbgView.tgtPos or dbgView.calcPos)
				view.angles = LerpAngle(frac, dbgView.startAng, dbgView.tgtAng or dbgView.calcAng)
			elseif frac == 1 and not dbgView.tgtPos then
				dbgView.flyStart = nil
			end
		end

		if dbgView.fovStart and dbgView.tgtFov then
			local st = math.Clamp(math.TimeFraction(dbgView.fovStart, dbgView.fovEnd, CurTime()), 0, 1)
			local frac = octolib.tween.easing.inOutQuad(st, 0, 1, 1)
			if frac > 0 then
				dbgView.fov = Lerp(frac, dbgView.startFov, dbgView.tgtFov)
			elseif frac == 1 then
				dbgView.fov = dbgView.tgtFov
				dbgView.fovStart = nil
			end
		end

		if dbgView.lookActive then
			local trace = util.TraceHull({
				start = dbgView.lookPosition,
				endpos = dbgView.lookPosition - dbgView.lookAngles:Forward() * dbgView.lookRadius,
				mins = Vector(-3, -3, -3),
				maxs = Vector(3, 3, 3),
				filter = ply,
			})

			view.origin = trace.HitPos
			view.angles = dbgView.lookAngles
		end

		dbgView.lastPos = view.origin
		dbgView.lastAng = view.angles

		return view
	else
		dbgView.viewpos = pos
	end

end

local function createMove(cmd)
	dbgView.realang = dbgView.realang + cmd:GetViewAngles() - prevang
	local veh = ply:GetVehicle()
	if IsValid(veh) then
		lookOffActive = false
		dbgView.realang.y = dbgView.realang.y - 90
		dbgView.realang:Normalize()
		dbgView.realang.y = math.Clamp(dbgView.realang.y, -110, 110)
		dbgView.realang.p = math.Clamp(dbgView.realang.p, -75, 10 + 35*(1-(math.abs(dbgView.realang.y)/135)^2))
		local negate = dbgView.realang.y < 0
		dbgView.realang.y = dbgView.realang.y + 90
		dbgView.realang.r = (negate and -1 or 1) * (math.pow(dbgView.realang.y - 90, 2)) * (dbgView.realang.p - 0) / 28000
	else
		dbgView.realang.p = math.Clamp(dbgView.realang.p, -75, 75)
		dbgView.realang.r = 0
	end
	dbgView.realang:Normalize()

	cmd:SetViewAngles(dbgView.realang)
	prevang = cmd:GetViewAngles()
end

local function shouldDrawLocalPlayer(ply)
	return true
end

local function hudShouldDraw(name)
	if name == 'CHudCrosshair' then return false end
end

local function hudPaint()
	if blind then
		draw.RoundedBox(0, -5, -5, ScrW()+10, ScrH()+10, color_black)
	end

end

hook.Add('dbg-view.chTraceOverride', 'octoweapons', function()
	local wep = LocalPlayer():GetActiveWeapon()
	if not IsValid(wep) or not wep.IsOctoWeapon then return end

	local pos, dir = wep:GetShootPosAndDir()
	return util.TraceLine({
		start = pos,
		endpos = pos + dir * 2000,
		filter = function(ent)
			return ent ~= ply and ent:GetRenderMode() ~= RENDERMODE_TRANSALPHA
		end
	})
end)

local dragging, isHands

local iconOn, iconOff = Material('octoteam/icons/hand_fist.png'), Material('octoteam/icons/hand.png')
hook.Add('dbg-view.chOverride', 'dbg_hands', function(tr)

	if dragging then
		tr.HitPos = dragging[1]
		tr.HitNormal = dragging[2]
		tr.Fraction = 0.05
		return iconOn, 255, 0.35
	elseif isHands and tr.Fraction < 0.05 then
		local ent = tr.Entity
		if IsValid(ent) and isHands.doNotDrag and not isHands.doNotDrag[ent:GetClass()] then
			return iconOff, 255, 0.35
		end
	end

end)

local delays = {}

surface.CreateFont('octolib.use', {
	font = 'Calibri',
	extended = true,
	size = 82,
	weight = 350,
})

surface.CreateFont('octolib.use-sh', {
	font = 'Calibri',
	extended = true,
	size = 82,
	weight = 350,
	blursize = 5,
})

local cx, cy = 0, 0
local size = 40
local p1, p2 = {}, {}
for i = 1, 36 do
	local a1 = math.rad((i-1) * -10 + 180)
	local a2 = math.rad(i * -10 + 180)
	p1[i] = { x = cx + math.sin(a1) * size, y = cy + math.cos(a1) * size }
	p2[i] = {
		{ x = cx, y = cy },
		{ x = cx + math.sin(a1) * size, y = cy + math.cos(a1) * size },
		{ x = cx + math.sin(a2) * size, y = cy + math.cos(a2) * size },
	}
end

hook.Add('dbg-view.chPaint', 'octolib.delay', function(tr, icon)

	for id, data in pairs(delays) do
		local segs = math.min(math.ceil((CurTime() - data.start) / data.time * 36), 36)
		local text = data.text .. ('.'):rep(math.floor(CurTime() * 2 % 4))
		draw.SimpleText(text, 'octolib.use-sh', 0 + 60, 0, color_black, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(text, 'octolib.use', 0 + 60, 0, Color(255,255,255, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		draw.NoTexture()
		surface.SetDrawColor(255,255,255, 50)
		surface.DrawPoly(p1)

		surface.SetDrawColor(255,255,255, 150)
		for i = 1, segs do
			surface.DrawPoly(p2[i])
		end

		timer.Simple(data.time, function()
			delays[id] = nil
		end)

		return true
	end

end)

hook.Add('dbg-view.chOverride', 'octolib.delay', function(tr, icon)

	local ply = LocalPlayer()
	if override and (not tr.Hit or tr.Fraction > 0.03) then
		local aim = (ply.viewAngs or ply:EyeAngles()):Forward()
		tr.HitPos = ply:GetShootPos() + aim * 60
		tr.HitNormal = -aim
		tr.Fraction = 0.03
	end

end)

function octolib.delay.add(time, text)
	local id = 'delay_' .. os.time() .. '_' .. math.random(1000,9999)
	local time = tonumber(time)
	delays[id] = {
		start = CurTime(),
		time = time,
		text = text,
	}
end

concommand.Add('delay', function(ply, cmd, args)
	if not args[1] or not args[2] then
		return octolib.notify.show('warning', 'delay "длительность" "текст"')
	end

	local time = tonumber(args[1])
	if not time or time <= 0 then
		return octolib.notify.show('warning', 'Неверный формат времени, либо оно отсутствует вовсе')
	end

	local text = table.concat(args, ' ', 2)
	octolib.delay.add(time, text)
	octolib.notify.show('hint', 'Delay = { time: ' .. time .. ', text: "' .. text .. '" }')
end)


-- hook.Add('mUrXkABDFgAjhexGVPMqqjKKMwuUFGj', 'octoweapons', function(e)
--     local e = LocalPlayer():GetActiveWeapon()
--     if IsValid(e) and e.OUbyFJsrOSBQGmSNEmXvNAbvYYqi then return false end
-- end)

local override = true

hook.Add('Think', 'dbg-view.checkwepandcar', function()
	local lp = LocalPlayer()
	local wep, veh = lp:GetActiveWeapon(), lp:GetVehicle()
	if IsValid(wep) and dbgView.disabledWeps[wep:GetClass()] or lp:InVehicle() then
		override = false
	else
		override = true
	end

end)

local function postDrawTranslucentRenderables()

	if not override then return end

	wep = ply:GetActiveWeapon()

	if wep.IsOctoWeapon then return end

	local aim = (ply.viewAngs or ply:EyeAngles()):Forward()
        local tr = hook.Run('dbg-view.chTraceOverride')
	if not tr then
		local pos = ply:GetShootPos()
		local endpos = pos + aim * 2000
		tr = util.TraceLine({
			start = pos,
			endpos = endpos,
			filter = function(ent)
				return ent ~= ply and ent:GetRenderMode() ~= RENDERMODE_TRANSALPHA
			end
		})
	end

	local _icon, _alpha, _scale = hook.Run('dbg-view.chOverride', tr)
	local n = tr.Hit and tr.HitNormal or -aim
	if math.abs(n.z) > 0.98 then
		n:Add(-aim * 0.01)
	end
	local chPos, chAng = LocalToWorld(chPosOff, chAngOff, tr.HitPos or endpos, n:Angle())
	cam.Start3D2D(chPos, chAng, math.pow(tr.Fraction, 0.5) * (_scale or 0.2))
	cam.IgnoreZ(true)
	if not hook.Run('dbg-view.chPaint', tr, _icon) then
		if _icon then surface.SetDrawColor(255,255,255, _alpha or 150)
		else
			local clr = color_white
			surface.SetDrawColor(clr.r, clr.g, clr.b, _alpha or 150)
		end
		surface.SetMaterial(_icon or chDefault)
		surface.DrawTexturedRect(-32, -32, 64, 64)
	end
	cam.IgnoreZ(false)
	cam.End3D2D()

end

local k_freeview, k_sights = KEY_LALT, MOUSE_MIDDLE
local function playerButtonDown(ply, key)
	if not IsFirstTimePredicted() then return end

	if key == k_freeview then lookOffActive = true end

	if key == k_sights then
		local wep = ply:GetActiveWeapon()
		if IsValid(wep) and wep:GetNWBool('IsReady') then
			dbgView.useSights = not dbgView.useSights
		end
	end

end
local function playerButtonUp(ply, key)
	if key == k_freeview and IsFirstTimePredicted() then lookOffActive = false end
end

local function turnOn()

	ply = LocalPlayer()
	dbgView.realang, dbgView.viewpos = ply:EyeAngles(), ply:GetShootPos()
	dbgView.lookOff = Angle()
	dbgView.fov = GetConVar('fov_desired'):GetFloat() or 90
	prevang = dbgView.realang
	k_freeview = KEY_LALT
	k_sights = MOUSE_MIDDLE

	hook.Add('Think', 'dbg-view', think)
	hook.Add('CalcView', 'dbg-view', calcView)
	hook.Add('CalcView', 'dbg-view.weapon', dbgView.calcWeaponView, -1)
	hook.Add('CreateMove', 'dbg-view', createMove)
	hook.Add('HUDPaint', 'dbg-view', hudPaint, -10)
	hook.Add('HUDShouldDraw', 'dbg-view', hudShouldDraw)
	hook.Add('InputMouseApply', 'dbg-view', inputMouseApply)
	hook.Add('PlayerButtonDown', 'dbg-view', playerButtonDown)
	hook.Add('PlayerButtonUp', 'dbg-view', playerButtonUp)

	hook.Add('PostDrawTranslucentRenderables', 'dbg-view', postDrawTranslucentRenderables)
	hook.Add('ShouldDrawLocalPlayer', 'dbg-view', shouldDrawLocalPlayer)

	dbgView.hideHead(true)

	recreateAnchor()
	timer.Create('dbg-view.validateAnchor', 10, 0, function()
		if not IsValid(anc) or ply:GetPos():DistToSqr(anc:GetPos()) > 10000 then
			recreateAnchor()
		end
	end)

	dbgView.active = true

end

local function turnOff()

	hook.Remove('Think', 'dbg-view')
	hook.Remove('CalcView', 'dbg-view')
	hook.Remove('CalcView', 'dbg-view.weapon')
	hook.Remove('CreateMove', 'dbg-view')
	hook.Remove('HUDPaint', 'dbg-view')
	hook.Remove('HUDShouldDraw', 'dbg-view')
	hook.Remove('InputMouseApply', 'dbg-view')
	hook.Remove('PlayerButtonDown', 'dbg-view')
	hook.Remove('PlayerButtonUp', 'dbg-view')
	-- hook.Remove('PostDrawTranslucentRenderables', 'dbg-view')
	hook.Remove('ShouldDrawLocalPlayer', 'dbg-view')

	dbgView.hideHead(false)

	if IsValid(anc) then anc:Remove() end
	timer.Remove('dbg-view.validateAnchor')

	dbgView.active = false

end

hook.Add('Think', 'dbg-view.override', function()

	local active = hook.Run('dbg-view.override') ~= false
	if not active and dbgView.active then
		turnOff()
	elseif active and not dbgView.active then
		turnOn()
	end

end)

local IsQuickLook = false

function dbgView.quicklook()
	if not dbgView.active then
		return octolib.notify.show('warning', 'Ты не можешь взглянуть на себя, когда держишь в руках физган, тулган или камеру')
	end

	if IsQuickLook then
		return octolib.notify.show('warning', 'Ты уже смотришь на себя')
	end

	IsQuickLook = true

	net.Start('dbg-quickLook')
	net.SendToServer()
	timer.Simple(0.3, function()
		local ply = LocalPlayer()

		local dir = dbgView.lastAng:Forward() + dbgView.lastAng:Right() * 0.3
		dir.z = -0.2
		dir:Normalize()

		local pos = dbgView.lastPos + dir * 40
		local tr = util.TraceHull({
			start = dbgView.lastPos,
			endpos = pos,
			mins = Vector(-3, -3, -3),
			maxs = Vector(3, 3, 3),
			filter = ply,
		})
		if tr.Hit then
			pos = tr.HitPos
		end

		local lpPos = ply:GetPos() + Vector(0, 0, 42)
		local ang = (lpPos - pos):Angle()
		dbgView.flyTo(pos, ang, 1)
		timer.Simple(0.2, function()
			dbgView.hideHead(false)
			-- ply:SetMaskVisible(true)
		end)
		local startPos = pos + ang:Forward() * dbgView.lastPos:Distance(pos)
		timer.Simple(1, function()
			dbgView.lookMod(true, startPos, ang, 40)
		end)

		local sphere = { radius = 300, alpha = 0 }
		hook.Add('PostDrawTranslucentRenderables', 'dbg-view.quickLook', function()
			render.SetColorMaterial()
			render.CullMode(MATERIAL_CULLMODE_CW)
			render.DrawSphere(lpPos, sphere.radius, 20, 20, Color(30,25,30, sphere.alpha))
			render.CullMode(MATERIAL_CULLMODE_CCW)
		end)

		octolib.tween.create(1, sphere, { radius = 50, alpha = 500 }, 'inOutQuad')

		timer.Simple(3, function()
			dbgView.flyTo(nil, nil, 1)
			dbgView.lookMod(false)
			timer.Simple(0.7, function()
				dbgView.hideHead(true)
				-- ply:SetMaskVisible(false)
			end)

			octolib.tween.create(1, sphere, { radius = 300, alpha = 0 }, 'inOutQuad', function()
				hook.Remove('PostDrawTranslucentRenderables', 'dbg-view.quickLook')
			end)
			IsQuickLook = false
		end)
	end)
end

concommand.Add('dbg-quickLook', dbgView.quicklook)

turnOff()

concommand.Add('cl_dbg_debug_view', function(_, _, args)
	if not LocalPlayer():IsAdmin() then 
		return octolib.notify.show('warning', 'Ты не можешь использовать эту комманду')
	end
	debugViewForwardDist = args[1] and tonumber(args[1])
end)