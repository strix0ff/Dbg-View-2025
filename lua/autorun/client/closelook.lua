dbgView = dbgView or {}
dbgView.look = dbgView.look or {
	enabled = false,
	state = 0,
	cache = {},
}

surface.CreateFont('dbg-hud.normal', {
	font = 'Calibri',
	extended = true,
	size = 27,
	weight = 350,
	shadow = true,
})
surface.CreateFont('dbg-hud.normal-sh', {
	font = 'Calibri',
	extended = true,
	size = 27,
	blursize = 5,
	weight = 350,
})

surface.CreateFont('dbg-hud.small', {
	font = 'Roboto',
	extended = true,
	size = 17,
	weight = 350,
	shadow = true,
})
surface.CreateFont('dbg-hud.small-sh', {
	font = 'Roboto',
	extended = true,
	size = 17,
	blursize = 4,
	weight = 350,
})

surface.CreateFont('octoinv.3d', {
	font = 'Arial Bold',
	extended = true,
	size = 18,
	weight = 300,
	antialias = true,
})

surface.CreateFont('octoinv.3d-sh', {
	font = 'Arial Bold',
	extended = true,
	size = 18,
	weight = 300,
	blursize = 5,
	antialias = true,
})

local look = dbgView.look

local key_on = KEY_G
-- cvars.AddChangeCallback('cl_dbg_key_look', function(cv, old, new) key_on = tonumber(new) end)

hook.Add('PlayerBindPress', 'dbg-look', function(ply, bind) if bind == '+zoom' then return true end end)
hook.Add('PlayerButtonDown', 'dbg-look', function(ply, key) if key == key_on and IsFirstTimePredicted() then look.enable(true) end end)
hook.Add('PlayerButtonUp', 'dbg-look', function(ply, key) if key == key_on and IsFirstTimePredicted() then look.enable(false) end end)

function look.enable(val)

	if val then
		look.enabled = true

		timer.Create('dbg-look', 0.4, 0, look.update)
		look.update()
	else
		look.enabled = false

		timer.Remove('dbg-look')
		for _, cache in pairs(look.cache) do
			cache.killing = true
		end
	end

end

local function getPos(ent, data)

	local pos, ang = ent:WorldSpaceCenter(), ent:GetAngles()
	if data.bone then
		local bone = ent:LookupBone(data.bone)
		if bone then pos, ang = ent:GetBonePosition(bone) end
	end
	if data.posRel then pos = LocalToWorld(data.posRel, angle_zero, pos, ang) end
	if data.posAbs then pos:Add(data.posAbs) end

	return pos, ang

end

local cos = math.cos(math.rad(40))
function look.update()

	local ply, found = LocalPlayer(), {}
	local ep = ply:EyePos()
	for _, ent in pairs(ents.FindInCone(ep, ply:GetAimVector(), 300, cos)) do
		local data = ent.dbgLook
		if data and not ent:GetNoDraw() then
			local pos = getPos(ent, data)
			local filter = { ply }
			if ply:InVehicle() then
				local veh = ply:GetVehicle()
				filter[#filter + 1] = veh
				filter[#filter + 1] = veh:GetParent()
			end
			if ent:IsPlayer() and ent:InVehicle() then
				local veh = ent:GetVehicle()
				filter[#filter + 1] = veh
				filter[#filter + 1] = veh:GetParent()
			end
			local tr = util.TraceLine({ start = ep, endpos = pos, filter = filter })
			if not tr.Hit or tr.Entity == ent then
				found[ent] = true
				if not look.cache[ent] then
					look.cache[ent] = {
						data = data,
						al = 0,
						rot = 0,
						descAl = 0,
						h = 0,
					}
				end
			end
		end
	end

	for ent, cache in pairs(look.cache) do
		cache.killing = not found[ent]
	end

end

hook.Add('EntityRemoved', 'dbg-look', function(ent)

	look.cache[ent] = nil

end)
local icon = Material('octoteam/icons/percent_inactive_white.png')
local st, mat = 0, Material('overlays/vignette01')
local colSh, colName = Color(0,0,0), Color(255,255,255)
local lp, job, efwd, alive, ghost, seesGhosts, medic, seesCaliber, admin, priest
hook.Add('Think', 'dbg-look', function()

	if not look.enabled and st == 0 then return end
	st = math.Approach(st, look.enabled and 1 or 0, FrameTime() * 1.5)

	look.state = octolib.tween.easing.outQuad(st, 0, 1, 1)

	lp = LocalPlayer()
	efwd = lp:GetAimVector()

	efwd.z = 0
	efwd:Normalize()

end)

hook.Add('HUDPaint', 'dbg-look', function()

	if st == 0 then return end

	mat:SetFloat('$alpha', look.state)
	render.SetMaterial(mat)
	render.DrawScreenQuad()

	local ft, cx, cy = FrameTime(), ScrW() / 2, ScrH() / 2
	for ent, cache in pairs(look.cache) do
		if not IsValid(ent) or (cache.al <= 0 and cache.killing) then
			look.cache[ent] = nil
		else
			cache.al = math.Approach(cache.al, cache.killing and 0 or 1, ft * 3)
			local al = octolib.tween.easing.outQuad(cache.al, 0, 1, 1)
			surface.SetAlphaMultiplier(al)

			local pos = getPos(ent, cache.data)
			pos = pos:ToScreen()

			local x, y = math.floor(pos.x), math.floor(pos.y)
			local spos = Vector(x, y, 0)
			if cache.data.lookOff then
				local off = cache.data.lookOff
				spos.x = spos.x - off.x
				spos.y = spos.y - off.y
			end
			local tAl = al * math.Clamp(220 - Vector(x, y, 0):DistToSqr(Vector(cx, cy, 0)) / 200, 0, 200) / 200
			local name, desc = cache.data.name, cache.data.desc

			local run, descAl, descOn = tAl == 1, cache.descAl, cache.descOn
			local descAlSm = descAl
			if desc and desc ~= '' then
				if descOn then
					local func = cache.data.descRender and look.render[desc]
					descAl = math.Approach(descAl, 1, ft * 1.5)
					descAlSm = al * octolib.tween.easing.outQuad(descAl, 0, 1, 1)
					if isfunction(func) then
						func(ent, cache, x, y, al, descAlSm)
					else
						cache.mu = cache.mu or markup.Parse(('<font=dbg-hud.small>%s</font>'):format(desc), 250)
						cache.h = cache.mu:GetHeight() / 2
						local my = y + 5 * descAlSm
						cache.mu:Draw(x, my, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 255 * descAl)
					end
				elseif run and descAl == 1 then
					descAl = 0
					descOn = true
					cache.lookTime = 0
				else
					descAl = math.Approach(descAl, run and 1 or 0, admin and ft * 5 or ft / (cache.data.time or 3))
				end
				cache.descAl = descAl
				cache.descOn = descOn

				local func = cache.data.checkLoader and look.render[cache.data.checkLoader]
				if not isfunction(func) or func(ent, cache) then
					if descOn then tAl = math.max(tAl - descAlSm, 0) end
					if tAl > 0 then
						local rot = (cache.rot - ft * (run and 240 or 90 * tAl)) % 360
						cache.rot = rot

						local iSize = descOn and (36 + 16 * descAlSm) or (36 * tAl)
						surface.SetMaterial(icon)
						surface.SetDrawColor(38, 166, 154, tAl * 255)
						surface.DrawTexturedRectRotated(x, y, iSize, iSize, rot)
					end
				end
			end

			local func = cache.data.nameRender and look.render[name]
			if isfunction(func) then
				func(ent, cache, x, y, al, descAlSm, descOn)
			else
				local ty = descOn and y - descAlSm * (cache.h + 5) or y
				draw.Text {
					text = name,
					font = 'dbg-hud.normal-sh',
					pos = {x, ty - 3},
					color = colSh,
					xalign = TEXT_ALIGN_CENTER,
					yalign = TEXT_ALIGN_CENTER,
				}
				draw.Text {
					text = name,
					font = 'dbg-hud.normal',
					pos = {x, ty - 3},
					color = colName,
					xalign = TEXT_ALIGN_CENTER,
					yalign = TEXT_ALIGN_CENTER,
				}
			end
		end
	end

	surface.SetAlphaMultiplier(1)

end)

hook.Add('PlayerFinishedLoading', 'dbg-hud', function()

	hook.Remove('PreDrawHalos', 'PropertiesHover')

end)

look.render = {
	playerName = function(ply, data, x, y, al1, al2, on)
		local ang2 = ply:GetAimVector()
		ang2.z = 0
		ang2:Normalize()

		local al = math.Clamp(1 - efwd:Dot(ang2) * 3, 0, 1)
		local ty = on and y - al2 * (data.h + 5) or y
		local name = ply:Name()
		draw.Text {
			text = name,
			font = 'dbg-hud.normal-sh',
			pos = {x, ty - 3},
			color = colSh,
			xalign = TEXT_ALIGN_CENTER,
			yalign = TEXT_ALIGN_CENTER,
		}
		draw.Text {
			text = name,
			font = 'dbg-hud.normal',
			pos = {x, ty - 3},
			color = colName,
			xalign = TEXT_ALIGN_CENTER,
			yalign = TEXT_ALIGN_CENTER,
		}
		data.nameAl = al
	end,
	playerDesc = function(ply, data, x, y, al1, al2)
		surface.SetAlphaMultiplier(al2)

		if data.mu then
			data.h = data.mu:GetHeight() / 2
			local my = y + 5 * al2
			data.mu:Draw(x, my, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 255 * al2)
		else
			local temp = {}
			temp[#temp + 1] = '- HP: ' .. ply:Health()
			temp[#temp + 1] = '- AR: ' .. ply:Armor()

			data.mu = markup.Parse('<font=dbg-hud.small>' .. table.concat(temp, '\n') .. '</font>', 300)
		end
	end,
}

for _, ply in ipairs(player.GetAll()) do
	ply.dbgLook = {
		name = 'playerName',
		nameRender = true,
		desc = 'playerDesc',
		descRender = true,
		time = 0.75,
		bone = 'ValveBiped.Bip01_Head1',
		posAbs = Vector(0, 0, 10),
		lookOff = Vector(0, -100, 0),
	}
end

local lastOnline = 0
timer.Create('updateOnline', 10, 0, function()
	if lastOnline ~= #player.GetAll() then
		for _, ply in ipairs(player.GetAll()) do
			ply.dbgLook = {
				name = 'playerName',
				nameRender = true,
				desc = 'playerDesc',
				descRender = true,
				time = 0.75,
				bone = 'ValveBiped.Bip01_Head1',
				posAbs = Vector(0, 0, 10),
				lookOff = Vector(0, -100, 0),
			}
		end
		lastOnline = #player.GetAll()
	end
end)