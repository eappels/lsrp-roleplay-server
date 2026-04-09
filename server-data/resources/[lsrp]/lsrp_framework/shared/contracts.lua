LSRPFramework = LSRPFramework or {}

LSRPFramework.Version = '1.6.0'
LSRPFramework.ContractVersion = '2026-04-09'

LSRPFramework.Resources = {
	core = 'lsrp_core',
	identity = 'lsrp_core',
	economy = 'lsrp_economy',
	jobs = 'lsrp_jobs',
	inventory = 'lsrp_inventory'
}

LSRPFramework.StateKeys = {
	hunger = 'lsrp_hunger',
	thirst = 'lsrp_thirst'
}

LSRPFramework.CallbackDefaults = {
	timeoutMs = 5000
}

LSRPFramework.CallbackEvents = {
	serverRequest = 'lsrp_framework:server:callback:request',
	serverResponse = 'lsrp_framework:server:callback:response',
	clientRequest = 'lsrp_framework:client:callback:request',
	clientResponse = 'lsrp_framework:client:callback:response'
}

LSRPFramework.NotificationLevels = {
	info = 'info',
	success = 'success',
	warning = 'warning',
	error = 'error'
}

LSRPFramework.ErrorCodes = {
	operation_failed = 'operation_failed',
	invalid_player = 'invalid_player',
	invalid_callback = 'invalid_callback',
	invalid_interaction = 'invalid_interaction',
	invalid_phone_app = 'invalid_phone_app',
	invalid_usable_item = 'invalid_usable_item',
	invalid_handler = 'invalid_handler',
	invalid_response = 'invalid_response',
	invalid_message = 'invalid_message',
	invalid_level = 'invalid_level',
	invalid_license = 'invalid_license',
	invalid_state_id = 'invalid_state_id',
	invalid_account_id = 'invalid_account_id',
	invalid_amount = 'invalid_amount',
	invalid_item = 'invalid_item',
	callback_failed = 'callback_failed',
	callback_not_registered = 'callback_not_registered',
	callback_already_registered = 'callback_already_registered',
	interaction_failed = 'interaction_failed',
	interaction_not_registered = 'interaction_not_registered',
	interaction_already_registered = 'interaction_already_registered',
	phone_app_not_registered = 'phone_app_not_registered',
	phone_app_already_registered = 'phone_app_already_registered',
	usable_item_not_registered = 'usable_item_not_registered',
	usable_item_already_registered = 'usable_item_already_registered',
	timeout = 'timeout',
	player_dropped = 'player_dropped',
	not_found = 'not_found',
	identity_unavailable = 'identity_unavailable',
	identity_error = 'identity_error',
	character_service_unavailable = 'character_service_unavailable',
	character_operation_failed = 'character_operation_failed',
	jobs_unavailable = 'jobs_unavailable',
	jobs_error = 'jobs_error',
	economy_unavailable = 'economy_unavailable',
	economy_error = 'economy_error',
	inventory_unavailable = 'inventory_unavailable',
	inventory_error = 'inventory_error'
}

LSRPFramework.ContractPolicy = {
	readModels = 'Documented read-model fields are stable within a contract version. New optional fields may be added without breaking the contract version.',
	breakingChanges = 'Field removals, field renames, type changes, or new required fields require a contract version bump.',
	errorCodes = 'Framework exports and callbacks should return documented framework error codes. Service-specific failures should be normalized before leaving the facade.'
}

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

local function buildLookup(values)
	local lookup = {}
	for key, value in pairs(values or {}) do
		local normalizedKey = trimString(key)
		if normalizedKey then
			lookup[normalizedKey] = true
		end

		local normalizedValue = trimString(value)
		if normalizedValue then
			lookup[normalizedValue] = true
		end
	end

	return lookup
end

local allowedNotificationLevels = buildLookup(LSRPFramework.NotificationLevels)
local allowedErrorCodes = buildLookup(LSRPFramework.ErrorCodes)

LSRPFramework.Validation = LSRPFramework.Validation or {}

LSRPFramework.Validation.trimString = trimString

LSRPFramework.Validation.normalizeNotificationLevel = function(value, fallback)
	local normalized = trimString(value)
	if normalized and allowedNotificationLevels[normalized] then
		return normalized
	end

	local normalizedFallback = trimString(fallback)
	if normalizedFallback and allowedNotificationLevels[normalizedFallback] then
		return normalizedFallback
	end

	return LSRPFramework.NotificationLevels.info
end

LSRPFramework.Validation.isKnownErrorCode = function(value)
	local normalized = trimString(value)
	return normalized ~= nil and allowedErrorCodes[normalized] == true or false
end

LSRPFramework.Validation.normalizeErrorCode = function(value, fallback)
	local normalized = trimString(value)
	if normalized and allowedErrorCodes[normalized] then
		return normalized
	end

	local normalizedFallback = trimString(fallback)
	if normalizedFallback and allowedErrorCodes[normalizedFallback] then
		return normalizedFallback
	end

	return LSRPFramework.ErrorCodes.operation_failed
end