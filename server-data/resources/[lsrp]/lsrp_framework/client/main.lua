local CALLBACK_DEFAULTS = LSRPFramework.CallbackDefaults or {}
local CALLBACK_EVENTS = LSRPFramework.CallbackEvents or {}
local registeredClientCallbacks = {}
local registeredNuiCallbacks = {}
local pendingServerCallbacks = {}
local clientCallbackRequestCounter = 0

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

local function normalizeCallbackName(value)
	return trimString(value)
end

local function normalizeEventName(value)
	return trimString(value)
end

local function normalizeTimeoutMs(value)
	local timeoutMs = math.floor(tonumber(value) or tonumber(CALLBACK_DEFAULTS.timeoutMs) or 5000)
	if timeoutMs < 1000 then
		return 1000
	end

	return timeoutMs
end

local function buildCallbackResponse(callbackName, requestId, ok, data, errorCode)
	return {
		ok = ok == true,
		data = ok == true and data or nil,
		error = ok == true and nil or (trimString(errorCode) or 'callback_failed'),
		meta = {
			callback = normalizeCallbackName(callbackName),
			requestId = trimString(requestId)
		}
	}
end

local function normalizeCallbackResponse(callbackName, requestId, response)
	if type(response) ~= 'table' then
		return buildCallbackResponse(callbackName, requestId, false, nil, 'invalid_response')
	end

	local meta = type(response.meta) == 'table' and response.meta or {}

	return {
		ok = response.ok == true,
		data = response.ok == true and response.data or nil,
		error = response.ok == true and nil or (trimString(response.error) or 'callback_failed'),
		meta = {
			callback = normalizeCallbackName(meta.callback) or normalizeCallbackName(callbackName),
			requestId = trimString(meta.requestId) or trimString(requestId)
		}
	}
end

local function normalizeCallbackHandlerResult(callbackName, requestId, result, data, errorCode)
	if type(result) == 'table' and (result.ok ~= nil or result.error ~= nil or result.data ~= nil or result.meta ~= nil) then
		return normalizeCallbackResponse(callbackName, requestId, result)
	end

	if type(result) == 'boolean' then
		return buildCallbackResponse(callbackName, requestId, result, data, errorCode)
	end

	return buildCallbackResponse(callbackName, requestId, true, result, nil)
end

local function nextClientCallbackRequestId()
	clientCallbackRequestCounter = clientCallbackRequestCounter + 1
	return ('cl:%s:%s:%s'):format(tostring(GetPlayerServerId(PlayerId())), tostring(GetGameTimer()), tostring(clientCallbackRequestCounter))
end

local function resolvePendingServerCallback(requestId, response)
	local pending = pendingServerCallbacks[requestId]
	if not pending then
		return false
	end

	pendingServerCallbacks[requestId] = nil
	pending.promise:resolve(normalizeCallbackResponse(pending.callbackName, requestId, response))
	return true
end

local function invokeRegisteredClientCallback(registration, callbackName, requestId, payload)
	if type(registration) ~= 'table' then
		return buildCallbackResponse(callbackName, requestId, false, nil, 'callback_not_registered')
	end

	if registration.kind == 'function' and type(registration.handler) == 'function' then
		local ok, result, data, errorCode = pcall(registration.handler, payload, {
			requestId = requestId,
			callback = callbackName
		})
		if not ok then
			return buildCallbackResponse(callbackName, requestId, false, nil, 'callback_failed')
		end

		return normalizeCallbackHandlerResult(callbackName, requestId, result, data, errorCode)
	end

	if registration.kind == 'event' and registration.eventName then
		local responsePromise = promise.new()
		local resolved = false

		local function resolve(response)
			if resolved then
				return
			end

			resolved = true
			responsePromise:resolve(response)
		end

		SetTimeout(normalizeTimeoutMs(), function()
			resolve(buildCallbackResponse(callbackName, requestId, false, nil, 'timeout'))
		end)

		local ok = pcall(function()
			TriggerEvent(registration.eventName, payload, {
				requestId = requestId,
				callback = callbackName
			}, function(result, data, errorCode)
				resolve(normalizeCallbackHandlerResult(callbackName, requestId, result, data, errorCode))
			end)
		end)

		if not ok then
			return buildCallbackResponse(callbackName, requestId, false, nil, 'callback_failed')
		end

		return Citizen.Await(responsePromise)
	end

	return buildCallbackResponse(callbackName, requestId, false, nil, 'invalid_handler')
end

local function invokeRegisteredNuiCallback(registration, callbackName, data)
	if type(registration) ~= 'table' then
		return buildCallbackResponse(callbackName, nil, false, nil, 'callback_not_registered')
	end

	if registration.kind == 'function' and type(registration.handler) == 'function' then
		local ok, result, callbackData, errorCode = pcall(registration.handler, data, {
			callback = callbackName,
			source = 'nui'
		})
		if not ok then
			return buildCallbackResponse(callbackName, nil, false, nil, 'callback_failed')
		end

		return normalizeCallbackHandlerResult(callbackName, nil, result, callbackData, errorCode)
	end

	if registration.kind == 'event' and registration.eventName then
		local responsePromise = promise.new()
		local resolved = false

		local function resolve(response)
			if resolved then
				return
			end

			resolved = true
			responsePromise:resolve(response)
		end

		SetTimeout(normalizeTimeoutMs(), function()
			resolve(buildCallbackResponse(callbackName, nil, false, nil, 'timeout'))
		end)

		local ok = pcall(function()
			TriggerEvent(registration.eventName, data, {
				callback = callbackName,
				source = 'nui'
			}, function(result, callbackData, errorCode)
				resolve(normalizeCallbackHandlerResult(callbackName, nil, result, callbackData, errorCode))
			end)
		end)

		if not ok then
			return buildCallbackResponse(callbackName, nil, false, nil, 'callback_failed')
		end

		return Citizen.Await(responsePromise)
	end

	return buildCallbackResponse(callbackName, nil, false, nil, 'invalid_handler')
end

local function notify(message, level)
	local text = tostring(message or '')
	if text == '' then
		return
	end

	if level == 'error' then
		text = ('~r~%s'):format(text)
	elseif level == 'success' then
		text = ('~g~%s'):format(text)
	elseif level == 'warning' then
		text = ('~y~%s'):format(text)
	end

	BeginTextCommandThefeedPost('STRING')
	AddTextComponentSubstringPlayerName(text)
	EndTextCommandThefeedPostTicker(false, true)
end

RegisterNetEvent('lsrp_framework:client:notify', function(message, level)
	notify(message, level)
end)

RegisterNetEvent(CALLBACK_EVENTS.clientResponse, function(requestId, response)
	local normalizedRequestId = trimString(requestId)
	if not normalizedRequestId then
		return
	end

	resolvePendingServerCallback(normalizedRequestId, response)
end)

RegisterNetEvent(CALLBACK_EVENTS.clientRequest, function(requestId, callbackName, payload)
	local normalizedName = normalizeCallbackName(callbackName)
	local normalizedRequestId = trimString(requestId) or ('cl:incoming:%s'):format(tostring(GetGameTimer()))
	local response

	if not normalizedName then
		response = buildCallbackResponse(nil, normalizedRequestId, false, nil, 'invalid_callback')
	else
		local registration = registeredClientCallbacks[normalizedName]
		if type(registration) ~= 'table' then
			response = buildCallbackResponse(normalizedName, normalizedRequestId, false, nil, 'callback_not_registered')
		else
			response = invokeRegisteredClientCallback(registration, normalizedName, normalizedRequestId, payload)
		end
	end

	TriggerServerEvent(CALLBACK_EVENTS.serverResponse, normalizedRequestId, response)
end)

exports('registerClientCallback', function(callbackName, handler)
	local normalizedName = normalizeCallbackName(callbackName)
	if not normalizedName then
		return false, 'invalid_callback'
	end

	if type(handler) ~= 'function' and type(handler) ~= 'string' then
		return false, 'invalid_handler'
	end

	if type(handler) == 'function' then
		registeredClientCallbacks[normalizedName] = {
			kind = 'function',
			handler = handler
		}
		return true, nil
	end

	local eventName = normalizeEventName(handler)
	if not eventName then
		return false, 'invalid_handler'
	end

	registeredClientCallbacks[normalizedName] = {
		kind = 'event',
		eventName = eventName
	}
	return true, nil
end)

exports('unregisterClientCallback', function(callbackName)
	local normalizedName = normalizeCallbackName(callbackName)
	if not normalizedName then
		return false, 'invalid_callback'
	end

	if registeredClientCallbacks[normalizedName] == nil then
		return false, 'callback_not_registered'
	end

	registeredClientCallbacks[normalizedName] = nil
	return true, nil
end)

exports('triggerServerCallback', function(callbackName, payload, timeoutMs)
	local normalizedName = normalizeCallbackName(callbackName)
	if not normalizedName then
		return buildCallbackResponse(nil, nil, false, nil, 'invalid_callback')
	end

	local requestId = nextClientCallbackRequestId()
	local responsePromise = promise.new()
	pendingServerCallbacks[requestId] = {
		callbackName = normalizedName,
		promise = responsePromise
	}

	SetTimeout(normalizeTimeoutMs(timeoutMs), function()
		resolvePendingServerCallback(requestId, buildCallbackResponse(normalizedName, requestId, false, nil, 'timeout'))
	end)

	TriggerServerEvent(CALLBACK_EVENTS.serverRequest, requestId, normalizedName, payload)
	return Citizen.Await(responsePromise)
end)

exports('registerNuiCallback', function(callbackName, handler)
	local normalizedName = normalizeCallbackName(callbackName)
	if not normalizedName then
		return false, 'invalid_callback'
	end

	if type(handler) ~= 'function' and type(handler) ~= 'string' then
		return false, 'invalid_handler'
	end

	if registeredNuiCallbacks[normalizedName] == true then
		return false, 'callback_already_registered'
	end

	if type(handler) == 'function' then
		registeredNuiCallbacks[normalizedName] = {
			kind = 'function',
			handler = handler
		}
	else
		local eventName = normalizeEventName(handler)
		if not eventName then
			return false, 'invalid_handler'
		end

		registeredNuiCallbacks[normalizedName] = {
			kind = 'event',
			eventName = eventName
		}
	end

	RegisterNUICallback(normalizedName, function(data, cb)
		cb(invokeRegisteredNuiCallback(registeredNuiCallbacks[normalizedName], normalizedName, type(data) == 'table' and data or {}))
	end)

	return true, nil
end)

exports('notify', function(message, level)
	notify(message, level)
end)