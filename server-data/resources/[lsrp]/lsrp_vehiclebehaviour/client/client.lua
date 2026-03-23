local IGNITION_STATE_BAG_KEY = 'lsrpIgnitionOn'
local LOCK_STATE_BAG_KEY = 'lsrpVehicleLocked'
local OWNED_VEHICLE_OWNER_STATE_BAG_KEY = 'lsrpVehicleOwner'
local OWNED_VEHICLE_OWNER_STATE_ID_BAG_KEY = 'lsrpVehicleOwnerStateId'
local KEY_ACCESS_MODE_DOOR = 'door'
local KEY_ACCESS_MODE_START = 'start'
local KEY_REQUEST_TIMEOUT_MS = 2000
local NO_KEY_NOTIFY_COOLDOWN_MS = 3000
local LOCKED_ENTRY_NOTIFY_COOLDOWN_MS = 2000
local keyRequestCounter = 0
local pendingKeyRequests = {}
local startAuthorizationRequestCounter = 0
local pendingStartAuthorizationRequests = {}
local keyCacheByAccessMode = {
	[KEY_ACCESS_MODE_DOOR] = {},
	[KEY_ACCESS_MODE_START] = {}
}
local inFlightKeyRequestsByAccessMode = {
	[KEY_ACCESS_MODE_DOOR] = {},
	[KEY_ACCESS_MODE_START] = {}
}
local noKeyNotifyByPlate = {}
local lockedEntryNotifyByPlate = {}
local lockedEntryAttemptVehicle = 0
local lockedEntryAttemptSeat = nil
local lockedEntryAttemptStartedAt = 0
local lockedEntryAttemptBlockedUntil = 0
local playerLicenseIdentifier = nil
local lockToggleRequestInFlight = false
local failedIgnitionAttemptUntilByVehicle = {}

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

local function setFailedIgnitionAttemptActive(vehicle, durationMs)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return
	end

	failedIgnitionAttemptUntilByVehicle[vehicle] = GetGameTimer() + math.max(100, math.floor(tonumber(durationMs) or 0))
	CreateThread(function()
		Wait(math.max(100, math.floor(tonumber(durationMs) or 0)) + 50)
		if failedIgnitionAttemptUntilByVehicle[vehicle] and failedIgnitionAttemptUntilByVehicle[vehicle] <= GetGameTimer() then
			failedIgnitionAttemptUntilByVehicle[vehicle] = nil
		end
	end)
end

local function isFailedIgnitionAttemptActive(vehicle)
	if vehicle == 0 then
		return false
	end

	local activeUntil = tonumber(failedIgnitionAttemptUntilByVehicle[vehicle])
	if not activeUntil then
		return false
	end

	if activeUntil <= GetGameTimer() then
		failedIgnitionAttemptUntilByVehicle[vehicle] = nil
		return false
	end

	return true
end

local function isVehicleOutOfFuel(vehicle)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return false
	end

	if GetResourceState('lsrp_fuel') ~= 'started' then
		return false
	end

	local ok, isOutOfFuel = pcall(function()
		return exports['lsrp_fuel']:isOutOfFuel(vehicle)
	end)

	return ok and isOutOfFuel == true
end

local function playFailedIgnitionAttempt(vehicle)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return
	end

	setFailedIgnitionAttemptActive(vehicle, 350)
	SetVehicleNeedsToBeHotwired(vehicle, false)
	SetVehicleUndriveable(vehicle, true)
	SetVehicleEngineOn(vehicle, true, false, true)

	CreateThread(function()
		Wait(350)
		if vehicle ~= 0 and DoesEntityExist(vehicle) then
			SetVehicleEngineOn(vehicle, false, true, true)
			SetVehicleUndriveable(vehicle, true)
			failedIgnitionAttemptUntilByVehicle[vehicle] = nil
		end
	end)
end

local function normalizeKeyAccessMode(accessMode)
	if tostring(accessMode or '') == KEY_ACCESS_MODE_START then
		return KEY_ACCESS_MODE_START
	end

	return KEY_ACCESS_MODE_DOOR
end

local function getKeyCacheForAccessMode(accessMode)
	local normalizedAccessMode = normalizeKeyAccessMode(accessMode)
	local keyCache = keyCacheByAccessMode[normalizedAccessMode]
	if keyCache == nil then
		keyCache = {}
		keyCacheByAccessMode[normalizedAccessMode] = keyCache
	end

	return keyCache
end

local function getInFlightKeyRequestsForAccessMode(accessMode)
	local normalizedAccessMode = normalizeKeyAccessMode(accessMode)
	local inFlightKeyRequests = inFlightKeyRequestsByAccessMode[normalizedAccessMode]
	if inFlightKeyRequests == nil then
		inFlightKeyRequests = {}
		inFlightKeyRequestsByAccessMode[normalizedAccessMode] = inFlightKeyRequests
	end

	return inFlightKeyRequests
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

	local localStateId = tonumber(LocalPlayer and LocalPlayer.state and LocalPlayer.state.state_id)
	if localStateId and localStateId > 0 then
		local entityState = Entity(vehicle).state
		if entityState then
			local ownerStateId = tonumber(entityState[OWNED_VEHICLE_OWNER_STATE_ID_BAG_KEY])
			if ownerStateId and ownerStateId > 0 then
				return ownerStateId == localStateId
			end
		end
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

local function setPlateKeyCache(accessMode, plate, hasKey, reason)
	if not plate then
		return
	end

	local keyCache = getKeyCacheForAccessMode(accessMode)
	keyCache[plate] = {
		hasKey = hasKey == true,
		reason = tostring(reason or ''),
		checkedAt = GetGameTimer()
	}
end

local function getCachedVehicleKeyAccess(vehicle, accessMode)
	local plate = getVehiclePlate(vehicle)
	if not plate then
		return nil, 'invalid_plate', nil
	end

	local keyCache = getKeyCacheForAccessMode(accessMode)
	local cacheEntry = keyCache[plate]
	if isKeyCacheValid(cacheEntry) then
		return cacheEntry.hasKey == true, cacheEntry.reason, plate
	end

	return nil, 'cache_miss', plate
end

local function requestVehicleKeyAccessByPlate(plate, forceRefresh, accessMode)
	local normalizedPlate = normalizePlate(plate)
	local normalizedAccessMode = normalizeKeyAccessMode(accessMode)
	if not normalizedPlate then
		return false, 'invalid_plate'
	end

	local keyCache = getKeyCacheForAccessMode(normalizedAccessMode)
	local inFlightKeyRequests = getInFlightKeyRequestsForAccessMode(normalizedAccessMode)

	if forceRefresh ~= true then
		local cacheEntry = keyCache[normalizedPlate]
		if isKeyCacheValid(cacheEntry) then
			return cacheEntry.hasKey == true, cacheEntry.reason
		end
	end

	if inFlightKeyRequests[normalizedPlate] then
		local timeoutAt = GetGameTimer() + KEY_REQUEST_TIMEOUT_MS
		while inFlightKeyRequests[normalizedPlate] and GetGameTimer() < timeoutAt do
			Wait(0)
		end

		local cacheEntry = keyCache[normalizedPlate]
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

	TriggerServerEvent('lsrp_vehiclebehaviour:server:requestKeyAccess', requestId, normalizedPlate, normalizedAccessMode)

	CreateThread(function()
		Wait(KEY_REQUEST_TIMEOUT_MS)
		local pendingRequest = pendingKeyRequests[requestId]
		if pendingRequest then
			pendingKeyRequests[requestId] = nil
			pendingRequest:resolve({
				plate = normalizedPlate,
				accessMode = normalizedAccessMode,
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
	local resultAccessMode = normalizeKeyAccessMode(result and result.accessMode or normalizedAccessMode)

	setPlateKeyCache(resultAccessMode, resultPlate, hasKey, reason)
	return hasKey, reason
end

local function requestVehicleKeyAccess(vehicle, forceRefresh, accessMode)
	local plate = getVehiclePlate(vehicle)
	local normalizedAccessMode = normalizeKeyAccessMode(accessMode)
	if not plate then
		return false, 'invalid_plate'
	end

	return requestVehicleKeyAccessByPlate(plate, forceRefresh, normalizedAccessMode)
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
		setPlateKeyCache(KEY_ACCESS_MODE_START, plate, true, reason)
	end

	return allowed, reason
end

local function canStartVehicle(vehicle)
	local hasLocalKey, localReason = requestVehicleKeyAccess(vehicle, true, KEY_ACCESS_MODE_START)
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

local function refreshVehicleKeyAccessAsync(vehicle, accessMode)
	local plate = getVehiclePlate(vehicle)
	local inFlightKeyRequests = getInFlightKeyRequestsForAccessMode(accessMode)
	if not plate or inFlightKeyRequests[plate] then
		return
	end

	CreateThread(function()
		requestVehicleKeyAccessByPlate(plate, true, accessMode)
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

local function notifyLockedVehicleEntry(plate)
	local keysConfig = getKeysConfig()
	if not keysConfig or keysConfig.notify == false then
		return
	end

	if not plate then
		notify('Vehicle is locked. Unlock it before entering')
		return
	end

	local now = GetGameTimer()
	local lastNotifyAt = lockedEntryNotifyByPlate[plate] or 0
	if (now - lastNotifyAt) < LOCKED_ENTRY_NOTIFY_COOLDOWN_MS then
		return
	end

	lockedEntryNotifyByPlate[plate] = now
	notify('Vehicle is locked. Unlock it before entering')
end

local function getLockedEntryHandleTryDurationMs()
	local keysConfig = getKeysConfig()
	local durationMs = tonumber(keysConfig and keysConfig.forcedEntryHandleTryMs)
	if not durationMs or durationMs < 100 then
		return 750
	end

	return math.floor(durationMs)
end

local function getLockedEntryRetryDelayMs()
	local keysConfig = getKeysConfig()
	local delayMs = tonumber(keysConfig and keysConfig.forcedEntryRetryDelayMs)
	if not delayMs or delayMs < 0 then
		return 150
	end

	return math.floor(delayMs)
end

local function getLockedEntryDoorRangePadding()
	local keysConfig = getKeysConfig()
	local padding = tonumber(keysConfig and keysConfig.forcedEntryDoorRangePadding)
	if not padding or padding < 0.1 then
		return 0.85
	end

	return padding + 0.0
end

local function resetLockedVehicleEntryAttempt()
	lockedEntryAttemptVehicle = 0
	lockedEntryAttemptSeat = nil
	lockedEntryAttemptStartedAt = 0
	lockedEntryAttemptBlockedUntil = 0
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

local function applyVehicleLockState(vehicle, shouldLock)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return
	end

	local locked = shouldLock == true
	SetVehicleDoorsLocked(vehicle, locked and 2 or 1)
	SetVehicleDoorsLockedForAllPlayers(vehicle, locked)
end

local function isVehicleLocked(vehicle)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return false
	end

	local entityState = Entity(vehicle).state
	if entityState and entityState[LOCK_STATE_BAG_KEY] ~= nil then
		return entityState[LOCK_STATE_BAG_KEY] == true
	end

	local lockStatus = GetVehicleDoorLockStatus(vehicle)
	return lockStatus == 2 or lockStatus == 4 or lockStatus == 7 or lockStatus == 10
end

local function getLockedVehicleEntryGuardState(vehicle)
	if vehicle == 0 or not DoesEntityExist(vehicle) or not isVehicleLocked(vehicle) then
		return false, nil, false
	end

	local plate = getVehiclePlate(vehicle)
	if isVehicleOwnedByLocalPlayer(vehicle) then
		return true, plate, false
	end

	local cachedHasKey, cachedReason, cachedPlate = getCachedVehicleKeyAccess(vehicle, KEY_ACCESS_MODE_DOOR)
	plate = cachedPlate or plate

	if cachedHasKey == true then
		return true, plate, false
	end

	if cachedReason == 'cache_miss' then
		refreshVehicleKeyAccessAsync(vehicle, KEY_ACCESS_MODE_DOOR)
		local inFlightKeyRequests = getInFlightKeyRequestsForAccessMode(KEY_ACCESS_MODE_DOOR)
		if plate and inFlightKeyRequests[plate] then
			return true, plate, true
		end
	end

	return false, plate, false
end

local function isPedNearLockedVehicleDoor(ped, vehicle)
	if ped == 0 or vehicle == 0 or not DoesEntityExist(ped) or not DoesEntityExist(vehicle) then
		return false
	end

	local pedCoords = GetEntityCoords(ped)
	local vehicleCoords = GetEntityCoords(vehicle)
	local dx = pedCoords.x - vehicleCoords.x
	local dy = pedCoords.y - vehicleCoords.y
	local minDimensions, maxDimensions = GetModelDimensions(GetEntityModel(vehicle))
	local halfWidth = math.max(math.abs(minDimensions.x), math.abs(maxDimensions.x))
	local interactionDistance = halfWidth + getLockedEntryDoorRangePadding()

	return (dx * dx + dy * dy) <= (interactionDistance * interactionDistance)
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

local function isWithinLockSoundBroadcastRange(vehicle)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return false
	end

	local keysConfig = getKeysConfig()
	local maxDistance = tonumber(keysConfig and keysConfig.lockSoundBroadcastRange)
	if not maxDistance or maxDistance <= 0 then
		maxDistance = 45.0
	end

	local ped = PlayerPedId()
	if ped == 0 or not DoesEntityExist(ped) then
		return true
	end

	local pedCoords = GetEntityCoords(ped)
	local vehicleCoords = GetEntityCoords(vehicle)
	local dx = pedCoords.x - vehicleCoords.x
	local dy = pedCoords.y - vehicleCoords.y
	local dz = pedCoords.z - vehicleCoords.z

	return (dx * dx + dy * dy + dz * dz) <= (maxDistance * maxDistance)
end

local function toggleVehicleLocks()
	local vehicleBehaviour = getVehicleBehaviourConfig()
	local keysConfig = getKeysConfig()
	if not vehicleBehaviour or vehicleBehaviour.enabled == false or not keysConfig or keysConfig.enabled == false then
		return
	end

	if lockToggleRequestInFlight then
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

	local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
	local plate = getVehiclePlate(vehicle)
	if not vehicleNetId or vehicleNetId == 0 or not plate then
		if keysConfig.notify ~= false then
			notify('Could not identify this vehicle')
		end
		return
	end

	lockToggleRequestInFlight = true
	TriggerServerEvent('lsrp_vehiclebehaviour:server:toggleVehicleLock', vehicleNetId, plate)

	SetTimeout(KEY_REQUEST_TIMEOUT_MS, function()
		lockToggleRequestInFlight = false
	end)
end

local function getLockToggleFailureMessage(reason)
	if isTransientKeyReason(reason) then
		return 'Vehicle key service is unavailable'
	end

	if reason == 'no_key' or reason == 'unowned_vehicle' then
		return 'You do not have the keys for this vehicle'
	end

	if reason == 'invalid_vehicle' or reason == 'invalid_plate' then
		return 'Could not identify this vehicle'
	end

	return 'Could not toggle vehicle lock'
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

RegisterNetEvent('lsrp_vehiclebehaviour:client:keyAccessResponse', function(requestId, plate, accessMode, hasKey, reason)
	local normalizedRequestId = tonumber(requestId)
	if not normalizedRequestId then
		return
	end

	local normalizedPlate = normalizePlate(plate)
	local normalizedAccessMode = normalizeKeyAccessMode(accessMode)
	if normalizedPlate then
		setPlateKeyCache(normalizedAccessMode, normalizedPlate, hasKey == true, reason)
	end

	local pendingRequest = pendingKeyRequests[normalizedRequestId]
	if pendingRequest then
		pendingKeyRequests[normalizedRequestId] = nil
		pendingRequest:resolve({
			plate = normalizedPlate,
			accessMode = normalizedAccessMode,
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

RegisterNetEvent('lsrp_vehiclebehaviour:client:applyVehicleLockState', function(vehicleNetId, shouldLock)
	local normalizedNetId = tonumber(vehicleNetId)
	if not normalizedNetId then
		return
	end

	local vehicle = NetworkGetEntityFromNetworkId(normalizedNetId)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return
	end

	applyVehicleLockState(vehicle, shouldLock == true)
end)

RegisterNetEvent('lsrp_vehiclebehaviour:client:lockToggleResult', function(success, shouldLock, reason, vehicleNetId)
	lockToggleRequestInFlight = false

	local keysConfig = getKeysConfig()
	if success ~= true then
		if keysConfig and keysConfig.notify ~= false then
			notify(getLockToggleFailureMessage(reason))
		end
		return
	end

	local normalizedNetId = tonumber(vehicleNetId)
	local vehicle = normalizedNetId and NetworkGetEntityFromNetworkId(normalizedNetId) or 0
	if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
		applyVehicleLockState(vehicle, shouldLock == true)
		playVehicleLockSound(vehicle, shouldLock == true)
	end

	if keysConfig and keysConfig.notify ~= false then
		notify((shouldLock == true) and 'Vehicle locked' or 'Vehicle unlocked')
	end
end)

RegisterNetEvent('lsrp_vehiclebehaviour:client:playVehicleLockSound', function(vehicleNetId, shouldLock, initiatorServerId)
	local localServerId = tonumber(GetPlayerServerId(PlayerId()))
	local normalizedInitiator = tonumber(initiatorServerId)
	if localServerId and normalizedInitiator and localServerId == normalizedInitiator then
		return
	end

	local normalizedNetId = tonumber(vehicleNetId)
	if not normalizedNetId then
		return
	end

	local vehicle = NetworkGetEntityFromNetworkId(normalizedNetId)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return
	end

	if not isWithinLockSoundBroadcastRange(vehicle) then
		return
	end

	playVehicleLockSound(vehicle, shouldLock == true)
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
		-- Turning ON: the local player or any occupant must have the key.
		local hasKey, reason = canStartVehicle(vehicle)
		if hasKey ~= true then
			if ignitionConfig.notify ~= false then
				notify(isTransientKeyReason(reason) and 'Vehicle key service is unavailable' or 'You do not have the keys for this vehicle')
			end
			setVehicleIgnitionState(vehicle, false)
			return
		end
	end

	if newIgnitionState == true and isVehicleOutOfFuel(vehicle) then
		playFailedIgnitionAttempt(vehicle)
		return
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

if type(AddStateBagChangeHandler) == 'function' and type(GetEntityFromStateBagName) == 'function' then
	AddStateBagChangeHandler(LOCK_STATE_BAG_KEY, nil, function(bagName, _, value)
		if value == nil then
			return
		end

		local entity = GetEntityFromStateBagName(bagName)
		if entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then
			return
		end

		applyVehicleLockState(entity, value == true)
	end)

	AddStateBagChangeHandler(IGNITION_STATE_BAG_KEY, nil, function(bagName, _, value)
		if value == nil then
			return
		end

		local entity = GetEntityFromStateBagName(bagName)
		if entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then
			return
		end

		-- If the local player is the driver, setVehicleIgnitionState already called
		-- SetVehicleEngineOn with instantly=false (startup sound). Skip here so the
		-- state bag handler does not interrupt the startup animation/sound.
		local localPed = PlayerPedId()
		if localPed ~= 0 and GetPedInVehicleSeat(entity, -1) == localPed then
			return
		end

		local ignitionOn = value == true
		SetVehicleNeedsToBeHotwired(entity, false)
		SetVehicleUndriveable(entity, not ignitionOn)
		SetVehicleEngineOn(entity, ignitionOn, true, true)
	end)
end

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
						if isFailedIgnitionAttemptActive(vehicle) then
							DisableControlAction(0, 71, true)
						else
							SetVehicleUndriveable(vehicle, true)
							SetVehicleEngineOn(vehicle, false, true, true)
							DisableControlAction(0, 71, true)
						end
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

CreateThread(function()
	while not NetworkIsSessionStarted() do
		Wait(250)
	end

	while true do
		local vehicleBehaviour = getVehicleBehaviourConfig()
		local keysConfig = getKeysConfig()
		local guardEnabled = vehicleBehaviour and vehicleBehaviour.enabled ~= false
			and keysConfig and keysConfig.enabled ~= false
			and keysConfig.preventForcedEntryWithKey ~= false

		if not guardEnabled then
			Wait(1000)
		else
			local ped = PlayerPedId()

			if ped == 0 or IsPedFatallyInjured(ped) or IsPedInAnyVehicle(ped, false) then
				resetLockedVehicleEntryAttempt()
				Wait(250)
			else
				local vehicle = GetVehiclePedIsTryingToEnter(ped)

				if vehicle ~= 0 and DoesEntityExist(vehicle) then
					local shouldBlockEntry, plate, isPendingKeyCheck = getLockedVehicleEntryGuardState(vehicle)
					local seat = GetSeatPedIsTryingToEnter(ped)

					if lockedEntryAttemptVehicle ~= vehicle or lockedEntryAttemptSeat ~= seat then
						lockedEntryAttemptVehicle = vehicle
						lockedEntryAttemptSeat = seat
						lockedEntryAttemptStartedAt = 0
						lockedEntryAttemptBlockedUntil = 0
					end

					if shouldBlockEntry then
						if isPendingKeyCheck then
							DisableControlAction(0, 23, true)
							ClearPedTasks(ped)
							lockedEntryAttemptStartedAt = 0
							lockedEntryAttemptBlockedUntil = 0
							Wait(0)
						elseif not isPedNearLockedVehicleDoor(ped, vehicle) then
							lockedEntryAttemptStartedAt = 0
							lockedEntryAttemptBlockedUntil = 0
							Wait(0)
						else
							local now = GetGameTimer()

							if lockedEntryAttemptBlockedUntil > now then
								DisableControlAction(0, 23, true)
								ClearPedTasks(ped)
								Wait(0)
							else
								if lockedEntryAttemptStartedAt == 0 then
									lockedEntryAttemptStartedAt = now
								elseif (now - lockedEntryAttemptStartedAt) >= getLockedEntryHandleTryDurationMs() then
									DisableControlAction(0, 23, true)
									ClearPedTasks(ped)
									lockedEntryAttemptStartedAt = 0
									lockedEntryAttemptBlockedUntil = now + getLockedEntryRetryDelayMs()
									notifyLockedVehicleEntry(plate)
								end

								Wait(0)
							end
						end
					else
						resetLockedVehicleEntryAttempt()
						Wait(0)
					end
				else
					resetLockedVehicleEntryAttempt()
					Wait(100)
				end
			end
		end
	end
end)
