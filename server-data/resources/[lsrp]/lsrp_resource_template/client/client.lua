local RESOURCE_NAME = GetCurrentResourceName()
local CALLBACK_NAMES = {
	exampleAction = RESOURCE_NAME .. ':server:exampleAction'
}
local INTERACTION_IDS = {
	exampleAction = RESOURCE_NAME .. ':exampleAction'
}

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

function Framework.triggerServerCallback(callbackName, payload, timeoutMs)
	if GetResourceState('lsrp_framework') ~= 'started' then
		return {
			ok = false,
			error = 'framework_unavailable',
			meta = {
				callback = trimString(callbackName)
			}
		}
	end

	local ok, response = pcall(function()
		return exports['lsrp_framework']:triggerServerCallback(callbackName, type(payload) == 'table' and payload or {}, timeoutMs)
	end)

	if not ok or type(response) ~= 'table' then
		return {
			ok = false,
			error = 'framework_callback_failed',
			meta = {
				callback = trimString(callbackName)
			}
		}
	end

	return response
end

function Framework.invokeInteraction(interactionName, payload)
	if GetResourceState('lsrp_framework') ~= 'started' then
		return {
			ok = false,
			error = 'framework_unavailable',
			meta = {
				interaction = trimString(interactionName)
			}
		}
	end

	local ok, response = pcall(function()
		return exports['lsrp_framework']:invokeInteraction(interactionName, type(payload) == 'table' and payload or {})
	end)

	if not ok or type(response) ~= 'table' then
		return {
			ok = false,
			error = 'interaction_failed',
			meta = {
				interaction = trimString(interactionName)
			}
		}
	end

	return response
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

local function handleExampleInteraction(payload, meta)
	local response = Framework.triggerServerCallback(CALLBACK_NAMES.exampleAction, payload, 5000)
	if response.ok == true then
		local data = type(response.data) == 'table' and response.data or {}
		Framework.notify(data.message or 'Example action completed.', 'success')
		debugPrint(('Example interaction completed via %s.'):format(tostring(meta and meta.interaction or INTERACTION_IDS.exampleAction)))
		return response
	end

	Framework.notify('Example action failed.', 'error')
	debugPrint(('Example interaction failed: %s'):format(tostring(response.error or 'unknown_error')))
	return response
end

local function registerFrameworkInteractions()
	if GetResourceState('lsrp_framework') ~= 'started' then
		return
	end

	exports['lsrp_framework']:registerInteraction(INTERACTION_IDS.exampleAction, handleExampleInteraction, {
		label = 'Template interaction',
		kind = 'marker'
	})
end

local function unregisterFrameworkInteractions()
	if GetResourceState('lsrp_framework') ~= 'started' then
		return
	end

	exports['lsrp_framework']:unregisterInteraction(INTERACTION_IDS.exampleAction)
end

AddEventHandler('onClientResourceStart', function(resourceName)
	if resourceName == 'lsrp_framework' or resourceName == GetCurrentResourceName() then
		registerFrameworkInteractions()
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	unregisterFrameworkInteractions()
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
						local response = Framework.invokeInteraction(INTERACTION_IDS.exampleAction, {
							marker = trimString(marker.label),
							coords = { x = marker.coords.x, y = marker.coords.y, z = marker.coords.z }
						})
						if response.ok ~= true and (response.error == 'framework_unavailable' or response.error == 'interaction_not_registered' or response.error == 'interaction_failed') then
							Framework.notify('Example interaction is unavailable right now.', 'error')
						end
						Wait(300)
					end
				end
			end
		end

		Wait(waitMs)
	end
end)