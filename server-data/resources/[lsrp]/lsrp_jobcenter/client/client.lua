local uiOpen = false
local nuiReady = false
local nuiOpened = false
local pendingOpenPayload = nil
local activeCenter = nil
local centerBlips = {}

local function trimString(value)
	if value == nil then
		return nil
	end

	local trimmed = tostring(value):gsub('^%s+', ''):gsub('%s+$', '')
	if trimmed == '' then
		return nil
	end

	return trimmed
end

local function notify(message)
	BeginTextCommandThefeedPost('STRING')
	AddTextComponentSubstringPlayerName(tostring(message or ''))
	EndTextCommandThefeedPostTicker(false, true)
end

local function debugTrace(message)
	print(('[lsrp_jobcenter] %s'):format(tostring(message or '')))
	if Config.Debug then
		notify(message)
	end
end

local function showHelpPrompt(message)
	BeginTextCommandDisplayHelp('STRING')
	AddTextComponentSubstringPlayerName(tostring(message or ''))
	EndTextCommandDisplayHelp(0, false, true, -1)
end

local function forceCloseNui()
	SetNuiFocus(false, false)
	SetNuiFocusKeepInput(false)
	SendNUIMessage({ action = 'close' })
end

local function flushPendingOpen()
	if not uiOpen or type(pendingOpenPayload) ~= 'table' then
		return
	end

	SendNUIMessage({
		action = 'open',
		payload = pendingOpenPayload
	})
end

local function destroyBlips()
	for _, blip in ipairs(centerBlips) do
		RemoveBlip(blip)
	end

	centerBlips = {}
end

local function createBlips()
	destroyBlips()

	for _, center in ipairs(Config.JobCenters or {}) do
		local blipConfig = center.blip
		if blipConfig and blipConfig.enabled ~= false then
			local blip = AddBlipForCoord(center.coords.x, center.coords.y, center.coords.z)
			SetBlipSprite(blip, math.floor(tonumber(blipConfig.sprite) or 407))
			SetBlipDisplay(blip, 4)
			SetBlipScale(blip, tonumber(blipConfig.scale) or 0.78)
			SetBlipColour(blip, math.floor(tonumber(blipConfig.color) or 46))
			SetBlipAsShortRange(blip, true)
			BeginTextCommandSetBlipName('STRING')
			AddTextComponentSubstringPlayerName(trimString(blipConfig.label) or trimString(center.name) or 'Job Center')
			EndTextCommandSetBlipName(blip)
			centerBlips[#centerBlips + 1] = blip
		end
	end
end

local function closeUi(silent, reason)
	uiOpen = false
	nuiOpened = false
	activeCenter = nil
	pendingOpenPayload = nil
	forceCloseNui()
	debugTrace(('UI closed%s'):format(reason and (' (' .. tostring(reason) .. ')') or ''))

	if not silent then
		notify('Closed job center.')
	end
end

local function openUi(center)
	if uiOpen or not center then
		debugTrace('Open request ignored because UI is already open or center was invalid.')
		return
	end

	notify('Job center opening...')
	debugTrace(('Opening UI for center %s'):format(tostring(center.id or 'unknown')))
	uiOpen = true
	nuiOpened = false
	activeCenter = center
	pendingOpenPayload = {
		centerId = center.id,
		currentEmployment = nil,
		jobs = {},
		loading = true
	}
	SetNuiFocus(true, true)
	SetNuiFocusKeepInput(false)
	flushPendingOpen()
	TriggerServerEvent('lsrp_jobcenter:server:requestOpen', center.id)
end

RegisterCommand('jobcenter', function()
	local center = (Config.JobCenters and Config.JobCenters[1]) or nil
	if not center then
		notify('No job center is configured.')
		return
	end

	openUi(center)
end, false)

RegisterNetEvent('lsrp_jobcenter:client:open', function(payload)
	payload = type(payload) == 'table' and payload or {}
	payload.loading = false
	pendingOpenPayload = payload
	notify('Job center data received.')
	debugTrace(('Received job center payload with %s jobs.'):format(tostring((payload.jobs and #payload.jobs) or 0)))

	if not uiOpen then
		debugTrace('Discarding payload because UI is no longer marked open.')
		forceCloseNui()
		return
	end

	flushPendingOpen()
end)

RegisterNetEvent('lsrp_jobcenter:client:result', function(payload)
	payload = type(payload) == 'table' and payload or {}

	if payload.message then
		notify(payload.message)
	end

	if payload.refresh and activeCenter then
		TriggerServerEvent('lsrp_jobcenter:server:requestOpen', activeCenter.id)
	end
end)

RegisterNUICallback('close', function(_, cb)
	debugTrace('NUI requested close.')
	closeUi(true, 'nui_close')
	cb({ ok = true })
end)

RegisterNUICallback('uiReady', function(_, cb)
	nuiReady = true
	debugTrace('NUI page reported ready.')
	if uiOpen then
		notify('Job center page ready.')
	end
	flushPendingOpen()
	cb({ ok = true })
end)

RegisterNUICallback('uiOpened', function(_, cb)
	nuiOpened = true
	pendingOpenPayload = nil
	debugTrace('NUI page reported rendered/opened.')
	notify('Job center UI rendered.')
	cb({ ok = true })
end)

RegisterNUICallback('apply', function(payload, cb)
	payload = type(payload) == 'table' and payload or {}
	if not uiOpen then
		cb({ ok = false, error = 'ui_not_open' })
		return
	end

	TriggerServerEvent('lsrp_jobcenter:server:apply', payload.jobId, payload.gradeId)
	cb({ ok = true })
end)

RegisterNUICallback('resign', function(_, cb)
	if not uiOpen then
		cb({ ok = false, error = 'ui_not_open' })
		return
	end

	TriggerServerEvent('lsrp_jobcenter:server:resign')
	cb({ ok = true })
end)

AddEventHandler('onClientResourceStart', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		nuiReady = false
		debugTrace('Resource started, forcing initial UI close.')
		closeUi(true, 'resource_start')
	end
end)

CreateThread(function()
	closeUi(true)
	createBlips()

	while true do
		local waitMs = 750
		local playerPed = PlayerPedId()

		if playerPed ~= 0 and DoesEntityExist(playerPed) then
			local playerCoords = GetEntityCoords(playerPed)
			local closestCenter = nil
			local closestDistance = nil

			for _, center in ipairs(Config.JobCenters or {}) do
				local distance = #(playerCoords - center.coords)

				if distance <= (tonumber(Config.DrawDistance) or 22.0) then
					waitMs = 0

					if Config.Marker and Config.Marker.enabled ~= false then
						DrawMarker(
							math.floor(tonumber(Config.Marker.type) or 27),
							center.coords.x,
							center.coords.y,
							center.coords.z - 0.96,
							0.0,
							0.0,
							0.0,
							0.0,
							0.0,
							0.0,
							(Config.Marker.scale and Config.Marker.scale.x) or 0.38,
							(Config.Marker.scale and Config.Marker.scale.y) or 0.38,
							(Config.Marker.scale and Config.Marker.scale.z) or 0.38,
							(Config.Marker.color and Config.Marker.color.r) or 242,
							(Config.Marker.color and Config.Marker.color.g) or 193,
							(Config.Marker.color and Config.Marker.color.b) or 78,
							(Config.Marker.color and Config.Marker.color.a) or 190,
							Config.Marker.bobUpAndDown == true,
							false,
							2,
							Config.Marker.rotate == true,
							nil,
							nil,
							false
						)
					end
				end

				if not closestDistance or distance < closestDistance then
					closestCenter = center
					closestDistance = distance
				end
			end

			if uiOpen and activeCenter and activeCenter.coords then
				local distanceFromCenter = #(playerCoords - activeCenter.coords)
				if distanceFromCenter > (tonumber(Config.AutoCloseDistance) or 6.0) then
					closeUi(true, 'walked_away')
					notify('You stepped away from the job center.')
				end
			end

			if not uiOpen and closestCenter and closestDistance and closestDistance <= (tonumber(Config.InteractionDistance) or 1.8) then
				showHelpPrompt(trimString(Config.OpenPrompt) or 'Press ~INPUT_CONTEXT~ to browse civilian jobs')
				if IsControlJustPressed(0, math.floor(tonumber(Config.InteractionKey) or 38)) then
					openUi(closestCenter)
				end
			end
		end

		Wait(waitMs)
	end
end)

CreateThread(function()
	while true do
		if uiOpen then
			if not nuiOpened and type(pendingOpenPayload) == 'table' then
				flushPendingOpen()
				Wait(350)
			else
				Wait(250)
			end
		else
			forceCloseNui()
			Wait(1500)
		end
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		debugTrace('Resource stopping, closing UI.')
		closeUi(true, 'resource_stop')
		destroyBlips()
	end
end)