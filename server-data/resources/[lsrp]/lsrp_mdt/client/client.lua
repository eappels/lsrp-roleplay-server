local uiOpen = false
local cachedPayload = nil

local function frameworkStarted()
	return GetResourceState('lsrp_framework') == 'started'
end

local function notify(message, level)
	if frameworkStarted() then
		exports['lsrp_framework']:notify(tostring(message or ''), level)
		return
	end

	BeginTextCommandThefeedPost('STRING')
	AddTextComponentSubstringPlayerName(tostring(message or ''))
	EndTextCommandThefeedPostTicker(false, true)
end

local function closeMdtUi()
	if not uiOpen then
		return
	end

	uiOpen = false
	SetNuiFocus(false, false)
	if type(SetNuiFocusKeepInput) == 'function' then
		SetNuiFocusKeepInput(false)
	end

	SendNUIMessage({ action = 'close' })
end

local function openMdtUi(payload)
	if uiOpen then
		closeMdtUi()
	end

	uiOpen = true
	cachedPayload = type(payload) == 'table' and payload or {}
	SetNuiFocus(true, true)
	if type(SetNuiFocusKeepInput) == 'function' then
		SetNuiFocusKeepInput(false)
	end

	SendNUIMessage({
		action = 'open',
		payload = cachedPayload
	})
end

RegisterNetEvent(GetCurrentResourceName() .. ':client:open', function(payload)
	openMdtUi(payload)
end)

RegisterNetEvent(GetCurrentResourceName() .. ':client:close', function()
	closeMdtUi()
end)

RegisterNetEvent(GetCurrentResourceName() .. ':client:update', function(payload)
	cachedPayload = type(payload) == 'table' and payload or {}
	SendNUIMessage({
		action = 'update',
		payload = cachedPayload
	})
	if uiOpen ~= true then
		openMdtUi(cachedPayload)
	end
end)

RegisterNUICallback('close', function(_, cb)
	closeMdtUi()
	cb({ ok = true })
end)

RegisterNUICallback('refreshMdt', function(_, cb)
	TriggerServerEvent(GetCurrentResourceName() .. ':server:requestRefresh')
	cb({ ok = true })
end)

RegisterNUICallback('mdtAction', function(data, cb)
	local action = type(data) == 'table' and tostring(data.event or data.action or 'action') or 'action'
	local query = type(data) == 'table' and tostring(data.query or '') or ''
	if action == 'close' then
		closeMdtUi()
		cb({ ok = true, data = { action = action, query = query } })
		return
	end

	TriggerServerEvent(GetCurrentResourceName() .. ':server:runAction', {
		action = action,
		query = query
	})
	cb({
		ok = true,
		data = {
			action = action,
			query = query
		}
	})
end)

AddEventHandler('onClientResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	closeMdtUi()
end)