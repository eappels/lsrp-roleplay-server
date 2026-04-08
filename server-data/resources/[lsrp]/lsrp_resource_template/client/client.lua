local RESOURCE_NAME = GetCurrentResourceName()

local Framework = {}

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

local function debugPrint(message)
	if Config.Debug ~= true then
		return
	end

	print(('[%s] %s'):format(RESOURCE_NAME, tostring(message)))
end

function Framework.notify(message, level)
	if GetResourceState('lsrp_framework') == 'started' then
		exports['lsrp_framework']:notify(trimString(message) or '', level)
		return
	end

	BeginTextCommandThefeedPost('STRING')
	AddTextComponentSubstringPlayerName(tostring(message or ''))
	EndTextCommandThefeedPostTicker(false, true)
end

local function showHelpPrompt(message)
	BeginTextCommandDisplayHelp('STRING')
	AddTextComponentSubstringPlayerName(tostring(message or ''))
	EndTextCommandDisplayHelp(0, false, false, -1)
end

local function isInteractionJustPressed()
	local control = math.floor(tonumber(Config.InteractionKey) or 38)
	return IsControlJustPressed(0, control) or IsDisabledControlJustPressed(0, control)
end

RegisterNetEvent(RESOURCE_NAME .. ':client:exampleResult', function(payload)
	payload = type(payload) == 'table' and payload or {}
	if payload.message then
		Framework.notify(payload.message, payload.success == true and 'success' or 'error')
	end
	debugPrint('Received example result payload from server.')
end)

CreateThread(function()
	while true do
		local waitMs = 750
		local playerPed = PlayerPedId()

		if Config.FeatureFlags and Config.FeatureFlags.enabled ~= false and playerPed ~= 0 and DoesEntityExist(playerPed) then
			local playerCoords = GetEntityCoords(playerPed)
			local marker = Config.Markers and Config.Markers.main or nil
			if marker and marker.coords then
				local drawDistance = tonumber(Config.DrawDistance) or 30.0
				local interactionDistance = tonumber(Config.InteractionDistance) or 2.0
				local distance = #(playerCoords - marker.coords)

				if distance <= drawDistance then
					waitMs = 0
					DrawMarker(1, marker.coords.x, marker.coords.y, marker.coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.25, 1.25, 0.65, 94, 176, 255, 110, false, false, 2, false, nil, nil, false)
				end

				if distance <= interactionDistance then
					showHelpPrompt(('Press ~INPUT_CONTEXT~ to trigger %s'):format(tostring(marker.label or 'the example interaction')))
					if isInteractionJustPressed() then
						TriggerServerEvent(RESOURCE_NAME .. ':server:exampleAction', {
							marker = trimString(marker.label),
							coords = { x = marker.coords.x, y = marker.coords.y, z = marker.coords.z }
						})
						Wait(300)
					end
				end
			end
		end

		Wait(waitMs)
	end
end)