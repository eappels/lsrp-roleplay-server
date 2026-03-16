local IGNITION_STATE_BAG_KEY = 'lsrpIgnitionOn'
local OWNED_VEHICLE_OWNER_STATE_BAG_KEY = 'lsrpVehicleOwner'
local KEY_REQUEST_TIMEOUT_MS = 2000
local NO_KEY_NOTIFY_COOLDOWN_MS = 3000
local keyRequestCounter = 0
local pendingKeyRequests = {}
local startAuthorizationRequestCounter = 0
local pendingStartAuthorizationRequests = {}
local keyCacheByPlate = {}
local inFlightKeyRequests = {}
local noKeyNotifyByPlate = {}
local playerLicenseIdentifier = nil

local function getVehicleBehaviourConfig()
	return Config and Config.VehicleBehaviour or nil
end

local function getIgnitionConfig()
	local vehicleBehaviour = getVehicleBehaviourConfig()
	return vehicleBehaviour and vehicleBehaviour.ignition or nil
end

local function getKeysConfig()
	local vehicleBehaviour = getVehicleBehaviourConfig()
	return vehicleBehaviour and vehicleBehaviour.keys or nil
end

local function notify(message)
	BeginTextCommandThefeedPost('STRING')
	AddTextComponentSubstringPlayerName(tostring(message or ''))
	EndTextCommandThefeedPostTicker(false, true)
end

local function normalizePlate(value)
	if value == nil then
		return nil
	end

	local trimmed = tostring(value):gsub('^%s+', ''):gsub('%s+$', '')
	if trimmed == '' then
		return nil
	end

	return string.upper(trimmed)
end

local function normalizeLicenseIdentifier(value)
	if value == nil then
		return nil
	end

	local trimmed = tostring(value):gsub('^%s+', ''):gsub('%s+$', '')
	if trimmed == '' then
		return nil
	end

	return string.lower(trimmed)
end

local function isTransientKeyReason(reason)
	local normalizedReason = tostring(reason or '')
	return normalizedReason == 'database_not_ready'
		or normalizedReason == 'database_error'
		or normalizedReason == 'request_timeout'
		or normalizedReason == 'missing_license'
end

local function isVehicleOwnedByLocalPlayer(vehicle)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return false
	end

	local localLicense = normalizeLicenseIdentifier(playerLicenseIdentifier)
	if not localLicense then
		return false
	end

	local entityState = Entity(vehicle).state
	if not entityState then
		return false
	end

	local ownerLicense = normalizeLicenseIdentifier(entityState[OWNED_VEHICLE_OWNER_STATE_BAG_KEY])
	if not ownerLicense then
		return false
	end

	return ownerLicense == localLicense
end

local function getVehiclePlate(vehicle)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return nil
	end

	return normalizePlate(GetVehicleNumberPlateText(vehicle))
end

local function collectVehicleOccupantServerIds(vehicle)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return {}
	end

	local occupantServerIds = {}
	local seenServerIds = {}
	local maxPassengers = tonumber(GetVehicleMaxNumberOfPassengers(vehicle)) or 0
	local maxSeatIndex = math.max(maxPassengers - 1, -1)

	for seat = -1, maxSeatIndex do
		local occupantPed = GetPedInVehicleSeat(vehicle, seat)
		if occupantPed ~= 0 and DoesEntityExist(occupantPed) and IsPedAPlayer(occupantPed) then
			local playerIndex = NetworkGetPlayerIndexFromPed(occupantPed)
			if playerIndex and playerIndex ~= -1 then
				local serverId = tonumber(GetPlayerServerId(playerIndex))
				if serverId and serverId > 0 and not seenServerIds[serverId] then
					seenServerIds[serverId] = true
					occupantServerIds[#occupantServerIds + 1] = serverId
				end
			end
		end
	end

	local localServerId = tonumber(GetPlayerServerId(PlayerId()))
	if localServerId and localServerId > 0 and not seenServerIds[localServerId] then
		occupantServerIds[#occupantServerIds + 1] = localServerId
	end

	return occupantServerIds
end

local function getKeyCacheDurationMs()
	local keysConfig = getKeysConfig()
	local cacheMs = tonumber(keysConfig and keysConfig.cacheMs)
	if not cacheMs or cacheMs < 1000 then
		return 6000
	end

	return math.floor(cacheMs)
end

local function isKeyCacheValid(cacheEntry)
	if type(cacheEntry) ~= 'table' then
		return false
	end

	local checkedAt = tonumber(cacheEntry.checkedAt)
	if not checkedAt then
		return false
	end

	return (GetGameTimer() - checkedAt) <= getKeyCacheDurationMs()
end

local function setPlateKeyCache(plate, hasKey, reason)
	if not plate then
		return
	end

	keyCacheByPlate[plate] = {
		hasKey = hasKey == true,
		reason = tostring(reason or ''),
		checkedAt = GetGameTimer()
	}
end

local function getCachedVehicleKeyAccess(vehicle)
	local plate = getVehiclePlate(vehicle)
	if not plate then
		return nil, 'invalid_plate', nil
	end

	local cacheEntry = keyCacheByPlate[plate]
	if isKeyCacheValid(cacheEntry) then
		return cacheEntry.hasKey == true, cacheEntry.reason, plate
	end

	return nil, 'cache_miss', plate
end

local function requestVehicleKeyAccessByPlate(plate, forceRefresh)
	local normalizedPlate = normalizePlate(plate)
	if not normalizedPlate then
		return false, 'invalid_plate'
	end

	if forceRefresh ~= true then
		local cacheEntry = keyCacheByPlate[normalizedPlate]
		if isKeyCacheValid(cacheEntry) then
			return cacheEntry.hasKey == true, cacheEntry.reason
		end
	end

	if inFlightKeyRequests[normalizedPlate] then
		local timeoutAt = GetGameTimer() + KEY_REQUEST_TIMEOUT_MS
		while inFlightKeyRequests[normalizedPlate] and GetGameTimer() < timeoutAt do
			Wait(0)
		end

		local cacheEntry = keyCacheByPlate[normalizedPlate]
		if isKeyCacheValid(cacheEntry) then
			return cacheEntry.hasKey == true, cacheEntry.reason
		end

		return false, 'request_timeout'
	end

	keyRequestCounter = keyRequestCounter + 1
	local requestId = keyRequestCounter
	local resultPromise = promise.new()
	pendingKeyRequests[requestId] = resultPromise
	inFlightKeyRequests[normalizedPlate] = true

	TriggerServerEvent('lsrp_vehiclebehaviour:server:requestKeyAccess', requestId, normalizedPlate)

	CreateThread(function()
		Wait(KEY_REQUEST_TIMEOUT_MS)
		local pendingRequest = pendingKeyRequests[requestId]
		if pendingRequest then
			pendingKeyRequests[requestId] = nil
			pendingRequest:resolve({
				plate = normalizedPlate,
				hasKey = false,
				reason = 'request_timeout'
			})
		end
	end)

	local result = Citizen.Await(resultPromise)
	inFlightKeyRequests[normalizedPlate] = nil

	local hasKey = result and result.hasKey == true
	local reason = result and result.reason or 'unknown'
	local resultPlate = normalizePlate(result and result.plate) or normalizedPlate

	setPlateKeyCache(resultPlate, hasKey, reason)
	return hasKey, reason
end

local function requestVehicleKeyAccess(vehicle, forceRefresh)
	local plate = getVehiclePlate(vehicle)
	if not plate then
		return false, 'invalid_plate'
	end

	if isVehicleOwnedByLocalPlayer(vehicle) then
		setPlateKeyCache(plate, true, 'owner_state')
		return true, 'owner_state'
	end

	local hasKey, reason = requestVehicleKeyAccessByPlate(plate, forceRefresh)
	if hasKey ~= true and isVehicleOwnedByLocalPlayer(vehicle) then
		setPlateKeyCache(plate, true, 'owner_state')
		return true, 'owner_state'
	end

	return hasKey, reason
end

local function requestVehicleStartAuthorization(vehicle)
	local plate = getVehiclePlate(vehicle)
	if not plate then
		return false, 'invalid_plate'
	end

	local occupantServerIds = collectVehicleOccupantServerIds(vehicle)
	if #occupantServerIds == 0 then
		return false, 'no_occupants'
	end

	startAuthorizationRequestCounter = startAuthorizationRequestCounter + 1
	local requestId = startAuthorizationRequestCounter
	local resultPromise = promise.new()
	pendingStartAuthorizationRequests[requestId] = resultPromise

	TriggerServerEvent('lsrp_vehiclebehaviour:server:requestStartAuthorization', requestId, plate, occupantServerIds)

	CreateThread(function()
		Wait(KEY_REQUEST_TIMEOUT_MS)
		local pendingRequest = pendingStartAuthorizationRequests[requestId]
		if pendingRequest then
			pendingStartAuthorizationRequests[requestId] = nil
			pendingRequest:resolve({
				allowed = false,
				reason = 'request_timeout'
			})
		end
	end)

	local result = Citizen.Await(resultPromise)
	local allowed = result and result.allowed == true
	local reason = result and result.reason or 'unknown'

	if allowed then
		setPlateKeyCache(plate, true, reason)
	end

	return allowed, reason
end

local function canStartVehicle(vehicle)
	local hasLocalKey, localReason = requestVehicleKeyAccess(vehicle, true)
	if hasLocalKey == true then
		return true, localReason
	end

	local hasOccupantKey, occupantReason = requestVehicleStartAuthorization(vehicle)
	if hasOccupantKey == true then
		return true, occupantReason
	end

	if isTransientKeyReason(occupantReason) then
		return false, occupantReason
	end

	if occupantReason == 'no_key' then
		return false, 'no_key'
	end

	return false, occupantReason or localReason
end

local function refreshVehicleKeyAccessAsync(vehicle)
	local plate = getVehiclePlate(vehicle)
	if not plate or inFlightKeyRequests[plate] then
		return
	end

	CreateThread(function()
		requestVehicleKeyAccessByPlate(plate, true)
	end)
end

local function notifyMissingVehicleKey(plate)
	if not plate then
		notify('You do not have the keys for this vehicle')
		return
	end

	local now = GetGameTimer()
	local lastNotifyAt = noKeyNotifyByPlate[plate] or 0
	if (now - lastNotifyAt) < NO_KEY_NOTIFY_COOLDOWN_MS then
		return
	end

	noKeyNotifyByPlate[plate] = now
	notify('You do not have the keys for this vehicle')
end

local function getVehicleForLockToggle(ped, maxDistance)
	if ped == 0 or IsPedFatallyInjured(ped) then
		return 0
	end

	if IsPedInAnyVehicle(ped, false) then
		return GetVehiclePedIsIn(ped, false)
	end

	local coords = GetEntityCoords(ped)
	local radius = tonumber(maxDistance) or 10.0
	return GetClosestVehicle(coords.x, coords.y, coords.z, radius + 0.0, 0, 71)
end

local function isVehicleLocked(vehicle)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return false
	end

	local lockStatus = GetVehicleDoorLockStatus(vehicle)
	return lockStatus == 2 or lockStatus == 4 or lockStatus == 7 or lockStatus == 10
end

local function playVehicleLockSound(vehicle, shouldLock)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return
	end

	local keysConfig = getKeysConfig()
	if not keysConfig or keysConfig.lockSoundEnabled == false then
		return
	end

	local soundMode = tostring(keysConfig.lockSoundMode or 'entity')
	if soundMode == 'door' then
		local useDoorOpenOnUnlock = keysConfig.unlockUseDoorOpenSound == true
		if shouldLock or not useDoorOpenOnUnlock then
			if type(PlayVehicleDoorCloseSound) == 'function' then
				PlayVehicleDoorCloseSound(vehicle, 0)
			end
		elseif type(PlayVehicleDoorOpenSound) == 'function' then
			PlayVehicleDoorOpenSound(vehicle, 0)
		end
		return
	end

	if soundMode == 'frontend' then
		local soundSet = tostring(keysConfig.frontendSoundSet or 'HUD_FRONTEND_DEFAULT_SOUNDSET')
		local lockSoundName = tostring(keysConfig.frontendLockSoundName or 'NAV_UP_DOWN')
		local unlockSoundName = tostring(keysConfig.frontendUnlockSoundName or 'NAV_UP_DOWN')
		local soundName = shouldLock and lockSoundName or unlockSoundName
		PlaySoundFrontend(-1, soundName, soundSet, true)
		return
	end

	local soundSet = tostring(keysConfig.lockSoundSet or 'PI_Menu_Sounds')
	local lockSoundName = tostring(keysConfig.lockSoundName or 'Remote_Control_Close')
	local unlockSoundName = tostring(keysConfig.unlockSoundName or 'Remote_Control_Open')
	local soundName = shouldLock and lockSoundName or unlockSoundName

	local soundId = GetSoundId()
	PlaySoundFromEntity(soundId, soundName, vehicle, soundSet, false, 0)
	ReleaseSoundId(soundId)
end

local function toggleVehicleLocks()
	local vehicleBehaviour = getVehicleBehaviourConfig()
	local keysConfig = getKeysConfig()
	if not vehicleBehaviour or vehicleBehaviour.enabled == false or not keysConfig or keysConfig.enabled == false then
		return
	end

	local ped = PlayerPedId()
	local vehicle = getVehicleForLockToggle(ped, keysConfig.lockSearchRadius)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		if keysConfig.notify ~= false then
			notify('No vehicle nearby to lock')
		end
		return
	end

	local hasKey, reason = requestVehicleKeyAccess(vehicle, true)
	if hasKey ~= true then
		if keysConfig.notify ~= false then
			notify(isTransientKeyReason(reason) and 'Vehicle key service is unavailable' or 'You do not have the keys for this vehicle')
		end
		return
	end

	local shouldLock = not isVehicleLocked(vehicle)
	SetVehicleDoorsLocked(vehicle, shouldLock and 2 or 1)
	SetVehicleDoorsLockedForAllPlayers(vehicle, shouldLock)
	playVehicleLockSound(vehicle, shouldLock)

	if keysConfig.notify ~= false then
		notify(shouldLock and 'Vehicle locked' or 'Vehicle unlocked')
	end
end

local function giveVehicleKeyToPlayer(targetServerId)
	local keysConfig = getKeysConfig()
	if not keysConfig or keysConfig.enabled == false then
		return
	end

	local ped = PlayerPedId()
	if ped == 0 or not IsPedInAnyVehicle(ped, false) then
		notify('You must be inside your vehicle to give a key')
		return
	end

	local vehicle = GetVehiclePedIsIn(ped, false)
	if vehicle == 0 or not DoesEntityExist(vehicle) or GetPedInVehicleSeat(vehicle, -1) ~= ped then
		notify('You must be in the driver seat to give a key')
		return
	end

	local plate = getVehiclePlate(vehicle)
	if not plate then
		notify('Could not read this vehicle plate')
		return
	end

	local targetId = tonumber(targetServerId)
	if not targetId or targetId <= 0 then
		notify('Usage: /givekey [server id]')
		return
	end

	TriggerServerEvent('lsrp_vehiclebehaviour:server:giveKey', targetId, plate)
end

RegisterNetEvent('lsrp_vehiclebehaviour:client:keyAccessResponse', function(requestId, plate, hasKey, reason)
	local normalizedRequestId = tonumber(requestId)
	if not normalizedRequestId then
		return
	end

	local normalizedPlate = normalizePlate(plate)
	if normalizedPlate then
		setPlateKeyCache(normalizedPlate, hasKey == true, reason)
	end

	local pendingRequest = pendingKeyRequests[normalizedRequestId]
	if pendingRequest then
		pendingKeyRequests[normalizedRequestId] = nil
		pendingRequest:resolve({
			plate = normalizedPlate,
			hasKey = hasKey == true,
			reason = tostring(reason or '')
		})
	end
end)

RegisterNetEvent('lsrp_vehiclebehaviour:client:startAuthorizationResponse', function(requestId, plate, allowed, reason)
	local normalizedRequestId = tonumber(requestId)
	if not normalizedRequestId then
		return
	end

	local pendingRequest = pendingStartAuthorizationRequests[normalizedRequestId]
	if pendingRequest then
		pendingStartAuthorizationRequests[normalizedRequestId] = nil
		pendingRequest:resolve({
			plate = normalizePlate(plate),
			allowed = allowed == true,
			reason = tostring(reason or '')
		})
	end
end)

RegisterNetEvent('lsrp_vehiclebehaviour:client:notify', function(message)
	notify(message)
end)

RegisterNetEvent('lsrp_vehiclebehaviour:client:setPlayerLicense', function(license)
	playerLicenseIdentifier = normalizeLicenseIdentifier(license)
end)

AddEventHandler('playerSpawned', function()
	TriggerServerEvent('lsrp_vehiclebehaviour:server:requestPlayerLicense')
end)

local function getVehicleIgnitionState(vehicle)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return nil
	end

	local entityState = Entity(vehicle).state
	if entityState == nil then
		return nil
	end

	local ignitionState = entityState[IGNITION_STATE_BAG_KEY]
	if ignitionState == nil then
		return nil
	end

	return ignitionState == true
end

local function setVehicleIgnitionState(vehicle, ignitionOn)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return
	end

	local entityState = Entity(vehicle).state
	if entityState then
		entityState:set(IGNITION_STATE_BAG_KEY, ignitionOn == true, true)
	end

	SetVehicleNeedsToBeHotwired(vehicle, false)
	if type(SetVehicleKeepEngineOnWhenAbandoned) == 'function' then
		SetVehicleKeepEngineOnWhenAbandoned(vehicle, ignitionOn == true)
	end

	if ignitionOn == true then
		SetVehicleUndriveable(vehicle, false)
		SetVehicleEngineOn(vehicle, true, false, true)
	else
		SetVehicleUndriveable(vehicle, true)
		SetVehicleEngineOn(vehicle, false, true, true)
	end

	if type(SetVehRadioStation) == 'function' and ignitionOn ~= true then
		SetVehRadioStation(vehicle, 'OFF')
	end
end

local function ensureVehicleIgnitionState(vehicle)
	local ignitionState = getVehicleIgnitionState(vehicle)
	if ignitionState ~= nil then
		return ignitionState
	end

	local currentEngineState = GetIsVehicleEngineRunning(vehicle)
	setVehicleIgnitionState(vehicle, currentEngineState)
	return currentEngineState
end

local function canToggleIgnition(ped, vehicle, ignitionConfig)
	if ped == 0 or IsPedFatallyInjured(ped) then
		return false
	end

	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return false
	end

	if ignitionConfig and ignitionConfig.driverSeatOnly ~= false and GetPedInVehicleSeat(vehicle, -1) ~= ped then
		return false
	end

	return true
end

local function toggleIgnition()
	local vehicleBehaviour = getVehicleBehaviourConfig()
	local ignitionConfig = getIgnitionConfig()
	local keysConfig = getKeysConfig()
	if not vehicleBehaviour or vehicleBehaviour.enabled == false or not ignitionConfig or ignitionConfig.enabled == false then
		return
	end

	local ped = PlayerPedId()
	if ped == 0 or not IsPedInAnyVehicle(ped, false) then
		return
	end

	local vehicle = GetVehiclePedIsIn(ped, false)
	if not canToggleIgnition(ped, vehicle, ignitionConfig) then
		return
	end

	local currentIgnitionState = ensureVehicleIgnitionState(vehicle)
	local newIgnitionState = not currentIgnitionState

	if newIgnitionState == true and keysConfig and keysConfig.enabled ~= false then
		local hasKey, reason = canStartVehicle(vehicle)
		if hasKey ~= true then
			if ignitionConfig.notify ~= false then
				notify(isTransientKeyReason(reason) and 'Vehicle key service is unavailable' or 'You do not have the keys for this vehicle')
			end
			setVehicleIgnitionState(vehicle, false)
			return
		end
	end

	setVehicleIgnitionState(vehicle, newIgnitionState)

	if ignitionConfig.notify ~= false then
		notify(newIgnitionState and 'Ignition on' or 'Ignition off')
	end
end

local defaultIgnitionKey = ((getIgnitionConfig() and getIgnitionConfig().key) or 'Z')
local defaultIgnitionModifierKey = tostring((getIgnitionConfig() and getIgnitionConfig().modifierKey) or ''):gsub('^%s+', ''):gsub('%s+$', '')
local ignitionModifierRequired = defaultIgnitionModifierKey ~= ''
local ignitionCommandName = ((getIgnitionConfig() and getIgnitionConfig().commandName) or 'ignition')
local ignitionKeyMappingCommand = '+' .. ignitionCommandName
local ignitionModifierCommandName = ignitionCommandName .. '_modifier'
local ignitionModifierKeyMappingCommand = '+' .. ignitionModifierCommandName
local ignitionPrimaryPressed = false
local ignitionModifierPressed = false
local defaultLockKey = ((getKeysConfig() and getKeysConfig().lockKey) or 'X')
local lockCommandName = ((getKeysConfig() and getKeysConfig().lockCommandName) or 'vehiclelock')
local lockKeyMappingCommandName = lockCommandName .. '_key'
local lockKeyMappingCommand = '+' .. lockKeyMappingCommandName
local lockKeyMappingReleaseCommand = '-' .. lockKeyMappingCommandName
local giveKeyCommandName = ((getKeysConfig() and getKeysConfig().giveCommandName) or 'givekey')

local function attemptIgnitionToggleFromKeybind()
	if ignitionModifierRequired ~= true then
		toggleIgnition()
		return
	end

	if ignitionPrimaryPressed and ignitionModifierPressed then
		toggleIgnition()
	end
end

RegisterCommand(ignitionCommandName, function()
	toggleIgnition()
end, false)

RegisterCommand(ignitionKeyMappingCommand, function()
	ignitionPrimaryPressed = true
	attemptIgnitionToggleFromKeybind()
end, false)

RegisterCommand('-' .. ignitionCommandName, function()
	ignitionPrimaryPressed = false
end, false)

RegisterKeyMapping(ignitionKeyMappingCommand, 'Toggle vehicle ignition', 'keyboard', defaultIgnitionKey)

if ignitionModifierRequired then
	RegisterCommand(ignitionModifierKeyMappingCommand, function()
		ignitionModifierPressed = true
		attemptIgnitionToggleFromKeybind()
	end, false)

	RegisterCommand('-' .. ignitionModifierCommandName, function()
		ignitionModifierPressed = false
	end, false)

	RegisterKeyMapping(ignitionModifierKeyMappingCommand, 'Ignition modifier', 'keyboard', defaultIgnitionModifierKey)
end

RegisterCommand(lockCommandName, function()
	toggleVehicleLocks()
end, false)

RegisterCommand(lockKeyMappingCommand, function()
	toggleVehicleLocks()
end, false)

RegisterCommand(lockKeyMappingReleaseCommand, function()
	-- Required by RegisterKeyMapping (+/- command pair).
end, false)

RegisterKeyMapping(lockKeyMappingCommand, 'Toggle vehicle lock', 'keyboard', defaultLockKey)

RegisterCommand(giveKeyCommandName, function(_, args)
	giveVehicleKeyToPlayer(args and args[1])
end, false)

CreateThread(function()
	while not NetworkIsSessionStarted() do
		Wait(250)
	end

	local vehicleBehaviour = getVehicleBehaviourConfig()
	if vehicleBehaviour and vehicleBehaviour.enabled ~= false then
		print('[lsrp_Vehiclebehaviour] Resource started')
	end

	TriggerServerEvent('lsrp_vehiclebehaviour:server:requestPlayerLicense')

	while true do
		local ignitionConfig = getIgnitionConfig()
		local vehicleBehaviourEnabled = vehicleBehaviour and vehicleBehaviour.enabled ~= false

		if not vehicleBehaviourEnabled or not ignitionConfig or ignitionConfig.enabled == false then
			Wait(1000)
		else
			local ped = PlayerPedId()

			if ped ~= 0 and IsPedInAnyVehicle(ped, false) then
				local vehicle = GetVehiclePedIsIn(ped, false)

				if vehicle ~= 0 and DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle, -1) == ped then
					local ignitionState = ensureVehicleIgnitionState(vehicle)

					if ignitionState ~= true then
						SetVehicleUndriveable(vehicle, true)
						SetVehicleEngineOn(vehicle, false, true, true)
						DisableControlAction(0, 71, true)
					else
						SetVehicleUndriveable(vehicle, false)
					end

					Wait(0)
				else
					Wait(250)
				end
			else
				Wait(250)
			end
		end
	end
end)
