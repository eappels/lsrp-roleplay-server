-- LSRP Spawner - Client Script
--
-- Handles the full player spawn sequence: fade-out, model change, coordinate
-- placement, ground-Z correction, and loading-screen teardown.
-- Also suppresses the idle camera and the front-seat shuffle input.
--
-- Exports:
--   spawnPlayerDirect(spawn) - spawn at the given spawn table
--     spawn = { x, y, z, heading, model?, skipFade? }
--
-- Net events received:
--   lsrp_spawner:spawnPlayer(model, x, y, z, heading) - server-triggered spawn
--
-- Flow on join:
--   CEventNetworkStartMatch -> TriggerServerEvent('lsrp_spawner:requestSpawn')
--   Server replies with 'lsrp_spawner:spawnPlayer' containing saved coords + outfit.

local loadscreenShutdownStarted = false
local shutdownRetryDurationMs = 10000
local shutdownRetryIntervalMs = 0
local spinnerGuardDeadline = 0
local spinnerGuardThreadActive = false
local persistentSpinnerGuardIntervalMs = 250
local GROUND_PROBE_TIMEOUT_MS = 2000
local GROUND_PROBE_STEP_HEIGHT = 12.0
local GROUND_PROBE_STEPS = 5
local MIN_GROUND_DELTA_FOR_CORRECTION = 0.75
local MAX_GROUND_DELTA_FOR_CORRECTION = 8.0
local GROUND_SPAWN_Z_OFFSET = 1.0
local DRIVER_SEAT_SHUFFLE_TIMEOUT_MS = 4000
local FIRST_CHARACTER_CREATION_SPAWN = {
	x = 403.16,
	y = -996.28,
	z = -99.00,
	heading = 174.67
}
local manualDriverSeatShuffleVehicle = 0
local manualDriverSeatShuffleExpiresAt = 0
local prejoinUiOpen = false
local prejoinAuthenticated = false
local prejoinCharacterReady = false
local prejoinStarted = false
local firstCharacterCreationActive = false
local freezeLocalPlayer
local spawnPlayerDirect
local prejoinSpawnPoints = {
	{ x = -1037.7, y = -2737.3, z = 20.17, heading = 0.0, label = 'Los Santos International', description = 'Airport arrivals and quick access to the south side.', mapX = 262, mapY = 508 },
	{ x = 215.76, y = -810.12, z = 30.73, heading = 180.0, label = 'Legion Square', description = 'Downtown access near jobs, shops, and garages.', mapX = 510, mapY = 436 },
	{ x = 369.67, y = -602.17, z = 28.87, heading = 142.11, label = 'Pillbox Hill', description = 'Central city spawn near the medical district.', mapX = 564, mapY = 390 }
}

-- ---------------------------------------------------------------------------
-- Loading screen helpers
-- ---------------------------------------------------------------------------

local function hideLoadingIndicators()
	if type(BusyspinnerOff) == 'function' then
		BusyspinnerOff()
	end

	if type(RemoveLoadingPrompt) == 'function' then
		RemoveLoadingPrompt()
	end
end

local function clearLoadingScreenNow()
	ShutdownLoadingScreen()
	hideLoadingIndicators()

	if type(ShutdownLoadingScreenNui) == 'function' then
		ShutdownLoadingScreenNui()
	end
end

local function keepClearingLoadingScreen(durationMs, intervalMs)
	local timeoutAt = GetGameTimer() + (durationMs or 3000)
	local interval = intervalMs or 100

	if timeoutAt > spinnerGuardDeadline then
		spinnerGuardDeadline = timeoutAt
	end

	if spinnerGuardThreadActive then
		return
	end

	spinnerGuardThreadActive = true

	CreateThread(function()
		while GetGameTimer() < spinnerGuardDeadline do
			clearLoadingScreenNow()
			Wait(interval)
		end

		spinnerGuardThreadActive = false
	end)
end

local function openPrejoinUi()
	if prejoinStarted then
		return
	end

	prejoinStarted = true
	prejoinUiOpen = true
	prejoinAuthenticated = false
	prejoinCharacterReady = false

	keepClearingLoadingScreen(3000, 0)
	SetNuiFocus(true, true)
	SetNuiFocusKeepInput(false)
	SendNUIMessage({
		action = 'showPrejoin',
		spawnPoints = prejoinSpawnPoints
	})
	TriggerServerEvent('lsrp_spawner:requestPrejoinSpawnOptions')
	freezeLocalPlayer(true)
	ShutdownLoadingScreen()
	if type(ShutdownLoadingScreenNui) == 'function' then
		ShutdownLoadingScreenNui()
	end
	DoScreenFadeIn(500)
end

local function getCharacterPreviewModel(sex)
	local normalizedSex = tostring(sex or ''):lower()
	if normalizedSex == 'female' then
		return (lsrpConfig and lsrpConfig.defaultFemalePedModel) or 'mp_f_freemode_01'
	end

	return (lsrpConfig and lsrpConfig.defaultMalePedModel) or 'mp_m_freemode_01'
end

local function getAirportSpawnPoint()
	for _, spawnPoint in ipairs(prejoinSpawnPoints) do
		local label = tostring(spawnPoint.label or ''):lower()
		local description = tostring(spawnPoint.description or ''):lower()
		if label:find('airport', 1, true) or label:find('international', 1, true) or description:find('airport', 1, true) then
			return spawnPoint
		end
	end

	return prejoinSpawnPoints[1]
end

local function beginFirstCharacterCreationSession(payload)
	payload = type(payload) == 'table' and payload or {}
	local previewModelName = getCharacterPreviewModel(payload.sex)
	local previewModelHash = tonumber(previewModelName) or GetHashKey(previewModelName)
	firstCharacterCreationActive = true
	prejoinUiOpen = false
	SetNuiFocus(false, false)
	SetNuiFocusKeepInput(false)

	CreateThread(function()
		spawnPlayerDirect({
			x = FIRST_CHARACTER_CREATION_SPAWN.x,
			y = FIRST_CHARACTER_CREATION_SPAWN.y,
			z = FIRST_CHARACTER_CREATION_SPAWN.z,
			heading = FIRST_CHARACTER_CREATION_SPAWN.heading,
			model = previewModelHash,
			skipFade = true,
			suppressPositionSave = true
		})

		Wait(150)
		TriggerEvent('lsrp_pededitor:openCharacterCreation')
	end)
end

RegisterNetEvent('lsrp_spawner:receivePrejoinSpawnOptions')
AddEventHandler('lsrp_spawner:receivePrejoinSpawnOptions', function(spawnOptions)
	if type(spawnOptions) == 'table' and #spawnOptions > 0 then
		prejoinSpawnPoints = spawnOptions
	end

	if prejoinUiOpen then
		SendNUIMessage({
			action = 'updateSpawnPoints',
			spawnPoints = prejoinSpawnPoints
		})
	end
end)

AddEventHandler('gameEventTriggered', function (name)
	if name == 'CEventNetworkStartMatch' then
		openPrejoinUi()
	end
end)

local function shutdownLoadscreen()
	if loadscreenShutdownStarted then
		return
	end

	loadscreenShutdownStarted = true
	hideLoadingIndicators()

	TriggerEvent('lsrp_loadscreen:shutdown')

	CreateThread(function()
		local timeoutAt = GetGameTimer() + shutdownRetryDurationMs

		while GetGameTimer() < timeoutAt do
			clearLoadingScreenNow()

			Wait(shutdownRetryIntervalMs)
		end
	end)
end

RegisterNUICallback('prejoinRegister', function(data, cb)
	local email = tostring(data.email or '')
	local password = tostring(data.password or '')
	local requestId = math.random(100000, 999999)
	local responded = false

	local function onResult(success, reason)
		if responded then
			return
		end

		responded = true
		cb({ success = success == true, reason = reason })
	end

	RegisterNetEvent('lsrp_prejoin:registerResult' .. requestId)
	AddEventHandler('lsrp_prejoin:registerResult' .. requestId, function(ok, reason)
		onResult(ok, reason)
	end)

	TriggerServerEvent('lsrp_prejoin:register', requestId, { email = email, password = password })
end)

RegisterNUICallback('prejoinLogin', function(data, cb)
	local email = tostring(data.email or '')
	local password = tostring(data.password or '')
	local requestId = math.random(100000, 999999)
	local responded = false

	local function onResult(success, reason)
		if responded then
			return
		end

		responded = true
		if success == true then
			prejoinAuthenticated = true
			prejoinCharacterReady = false
		end
		cb({ success = success == true, reason = reason })
	end

	RegisterNetEvent('lsrp_prejoin:loginResult' .. requestId)
	AddEventHandler('lsrp_prejoin:loginResult' .. requestId, function(ok, reason)
		onResult(ok, reason)
	end)

	TriggerServerEvent('lsrp_prejoin:login', requestId, { email = email, password = password })
end)

RegisterNUICallback('prejoinGetCharacter', function(_, cb)
	local requestId = math.random(100000, 999999)
	local responded = false

	local function onResult(payload)
		if responded then
			return
		end

		responded = true
		if payload and payload.success == true and payload.hasCharacter == true then
			prejoinCharacterReady = true
		else
			prejoinCharacterReady = false
		end

		cb(payload or { success = false, reason = 'empty_response' })
	end

	RegisterNetEvent('lsrp_spawner:receiveCurrentCharacter' .. requestId)
	AddEventHandler('lsrp_spawner:receiveCurrentCharacter' .. requestId, function(payload)
		onResult(payload)
	end)

	TriggerServerEvent('lsrp_spawner:requestCurrentCharacter', requestId)
end)

RegisterNUICallback('prejoinCreateCharacter', function(data, cb)
	local requestId = math.random(100000, 999999)
	local responded = false

	local function onResult(payload)
		if responded then
			return
		end

		responded = true
		if payload and payload.success == true and type(payload.character) == 'table' then
			prejoinCharacterReady = true
		else
			prejoinCharacterReady = false
		end

		cb(payload or { success = false, reason = 'empty_response' })
	end

	RegisterNetEvent('lsrp_spawner:createCharacterResult' .. requestId)
	AddEventHandler('lsrp_spawner:createCharacterResult' .. requestId, function(payload)
		onResult(payload)
	end)

	TriggerServerEvent('lsrp_spawner:createCharacter', requestId, data or {})
end)

RegisterNUICallback('prejoinBeginFirstCharacterCreation', function(data, cb)
	beginFirstCharacterCreationSession(data or {})
	cb({ success = true })
end)

RegisterNUICallback('prejoinSpawnSelect', function(data, cb)
	local spawnIndex = tonumber(data.spawnIndex)
	local spawn = spawnIndex and prejoinSpawnPoints[spawnIndex + 1] or nil

	if not prejoinAuthenticated then
		cb({ success = false, reason = 'Login first.' })
		return
	end

	if not prejoinCharacterReady then
		cb({ success = false, reason = 'Create a character first.' })
		return
	end

	if not spawn then
		cb({ success = false, reason = 'Invalid spawn.' })
		return
	end

	prejoinUiOpen = false
	firstCharacterCreationActive = false
	SetNuiFocus(false, false)
	SetNuiFocusKeepInput(false)
	cb({ success = true })
	TriggerServerEvent('lsrp_spawner:requestSelectedSpawn', spawnIndex + 1)
end)

-- ---------------------------------------------------------------------------
-- Spawn helpers
-- ---------------------------------------------------------------------------

-- Freezes or unfreezes the local player (control, visibility, collision, invincibility).
freezeLocalPlayer = function(freeze)
	local player = PlayerId()
	SetPlayerControl(player, not freeze, false)

	local ped = PlayerPedId()

	if not freeze then
		if not IsEntityVisible(ped) then
			SetEntityVisible(ped, true)
		end

		if not IsPedInAnyVehicle(ped, false) then
			SetEntityCollision(ped, true, true)
		end

		FreezeEntityPosition(ped, false)
		SetPlayerInvincible(player, false)
	else
		if IsEntityVisible(ped) then
			SetEntityVisible(ped, false)
		end

		SetEntityCollision(ped, false, false)
		FreezeEntityPosition(ped, true)
		SetPlayerInvincible(player, true)

		if not IsPedFatallyInjured(ped) then
			ClearPedTasksImmediately(ped)
		end
	end
end

-- Probes for solid ground at (x, y) from above, returning the Z of the first
-- hit or nil on timeout. Used to prevent players from spawning under the map.
local function findGroundZ(x, y, z)
	local timeoutAt = GetGameTimer() + GROUND_PROBE_TIMEOUT_MS

	while GetGameTimer() < timeoutAt do
		for step = 1, GROUND_PROBE_STEPS do
			local probeZ = z + (step * GROUND_PROBE_STEP_HEIGHT)

			RequestCollisionAtCoord(x, y, probeZ)

			local found, groundZ = GetGroundZFor_3dCoord(x, y, probeZ, false)
			if found then
				-- Ensure groundZ is within a reasonable range to avoid rooftops
				if math.abs(groundZ - z) < MAX_GROUND_DELTA_FOR_CORRECTION then
					return groundZ
				end
			end
		end

		Wait(0)
	end

	return nil
end

local function getSafeSpawnZ(x, y, z)
	if GetInteriorAtCoords(x, y, z) ~= 0 then
		return z, false
	end

	local groundZ = findGroundZ(x, y, z)
	if not groundZ then
		-- Fallback to a default safe Z if ground probing fails
		return z + GROUND_SPAWN_Z_OFFSET, false
	end

	local groundDelta = groundZ - z

	if groundDelta > MIN_GROUND_DELTA_FOR_CORRECTION and groundDelta <= MAX_GROUND_DELTA_FOR_CORRECTION then
		return groundZ + GROUND_SPAWN_Z_OFFSET, true
	end

	return z, false
end

-- Full spawn sequence: fade, model load, coord set, ground correction, unfade.
-- Fires 'playerSpawned' local event on completion.
spawnPlayerDirect = function(spawn)
	prejoinUiOpen = false
	SetNuiFocus(false, false)
	SetNuiFocusKeepInput(false)

	local spawnX = tonumber(spawn.x) or 0.0
	local spawnY = tonumber(spawn.y) or 0.0
	local spawnZ = tonumber(spawn.z) or 72.0
	local spawnHeading = tonumber(spawn.heading) or 0.0

	local initialSafeZ, _ = getSafeSpawnZ(spawnX, spawnY, spawnZ)
	spawnZ = initialSafeZ

	spawn.x = spawnX
	spawn.y = spawnY
	spawn.z = spawnZ
	spawn.heading = spawnHeading

	if not spawn.skipFade then
		DoScreenFadeOut(0)

		while not IsScreenFadedOut() do
			Wait(0)
		end
	end

	freezeLocalPlayer(true)

	if spawn.model and IsModelInCdimage(spawn.model) and IsModelValid(spawn.model) then
		RequestModel(spawn.model)

		local modelTimeout = GetGameTimer() + 10000

		while not HasModelLoaded(spawn.model) do
			RequestModel(spawn.model)
			Wait(0)

			if GetGameTimer() > modelTimeout then
				break
			end
		end

		if HasModelLoaded(spawn.model) then
			SetPlayerModel(PlayerId(), spawn.model)
			SetModelAsNoLongerNeeded(spawn.model)
		end
	end

	RequestCollisionAtCoord(spawnX, spawnY, spawnZ)

	local ped = PlayerPedId()
	SetEntityCoordsNoOffset(ped, spawnX, spawnY, spawnZ, false, false, false, true)
	NetworkResurrectLocalPlayer(spawnX, spawnY, spawnZ, spawnHeading, true, true, false)
	SetPedDefaultComponentVariation(ped)

	ClearPedTasksImmediately(ped)
	RemoveAllPedWeapons(ped)
	ClearPlayerWantedLevel(PlayerId())

	local time = GetGameTimer()

	while (not HasCollisionLoadedAroundEntity(ped) and (GetGameTimer() - time) < 5000) do
		Wait(0)
	end

	local correctedZ, corrected = getSafeSpawnZ(spawnX, spawnY, spawnZ)
	if corrected then
		spawnZ = correctedZ
		spawn.z = spawnZ

		SetEntityCoordsNoOffset(ped, spawnX, spawnY, spawnZ, false, false, false, true)
		NetworkResurrectLocalPlayer(spawnX, spawnY, spawnZ, spawnHeading, true, true, false)
	end

	shutdownLoadscreen()

	if IsScreenFadedOut() then
		DoScreenFadeIn(500)

		while not IsScreenFadedIn() do
			Wait(0)
		end
	end

	freezeLocalPlayer(false)
	if not spawn.suppressPositionSave then
		TriggerServerEvent('lsrp_core:savePosition', {
			x = spawnX,
			y = spawnY,
			z = spawnZ,
			heading = spawnHeading
		})
	end

	TriggerEvent('playerSpawned', spawn)
end

exports('spawnPlayerDirect', spawnPlayerDirect)

AddEventHandler('lsrp_pededitor:firstCharacterCreationFinished', function()
	if not firstCharacterCreationActive then
		return
	end

	local airportSpawn = getAirportSpawnPoint()
	if not airportSpawn then
		return
	end

	firstCharacterCreationActive = false
	spawnPlayerDirect(airportSpawn)
end)

local function movePedToDriverSeat()
	local ped = PlayerPedId()
	if ped == 0 or IsPedFatallyInjured(ped) or not IsPedInAnyVehicle(ped, false) then
		return
	end

	local vehicle = GetVehiclePedIsIn(ped, false)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return
	end

	if GetPedInVehicleSeat(vehicle, 0) ~= ped then
		return
	end

	if GetPedInVehicleSeat(vehicle, -1) ~= 0 then
		return
	end

	manualDriverSeatShuffleVehicle = vehicle
	manualDriverSeatShuffleExpiresAt = GetGameTimer() + DRIVER_SEAT_SHUFFLE_TIMEOUT_MS

	TaskShuffleToNextVehicleSeat(ped, vehicle)

	CreateThread(function()
		local timeoutAt = manualDriverSeatShuffleExpiresAt

		while manualDriverSeatShuffleVehicle == vehicle and GetGameTimer() < timeoutAt do
			if not DoesEntityExist(vehicle) or not IsPedInVehicle(ped, vehicle, false) then
				break
			end

			if GetPedInVehicleSeat(vehicle, -1) == ped then
				manualDriverSeatShuffleVehicle = 0
				manualDriverSeatShuffleExpiresAt = 0
				return
			end

			Wait(0)
		end

		if manualDriverSeatShuffleVehicle == vehicle then
			if DoesEntityExist(vehicle) and IsPedInVehicle(ped, vehicle, false) and GetPedInVehicleSeat(vehicle, 0) == ped and GetPedInVehicleSeat(vehicle, -1) == 0 then
				SetPedIntoVehicle(ped, vehicle, -1)
			end

			manualDriverSeatShuffleVehicle = 0
			manualDriverSeatShuffleExpiresAt = 0
		end
	end)
end

RegisterCommand('driverseat', function()
	movePedToDriverSeat()
end, false)

RegisterCommand('+driverseat', function()
	movePedToDriverSeat()
end, false)

RegisterCommand('-driverseat', function()
	-- Required by RegisterKeyMapping (+/- command pair).
end, false)

RegisterKeyMapping('+driverseat', 'Move from front passenger to driver seat', 'keyboard', 'LMENU')

RegisterNetEvent('lsrp_spawner:spawnPlayer')
AddEventHandler('lsrp_spawner:spawnPlayer', function(modelOrNil, ax, ay, az, aHeading)
	local model = modelOrNil or 'mp_m_freemode_01'
	local modelHash = tonumber(model) or GetHashKey(model)

	local ped = PlayerPedId()
	local pos = GetEntityCoords(ped)
	local heading = GetEntityHeading(ped)

	local sx = tonumber(ax) or pos.x
	local sy = tonumber(ay) or pos.y
	local sz = tonumber(az) or pos.z
	local sh = tonumber(aHeading) or heading

	local spawnTable = {
		x = sx,
		y = sy,
		z = sz,
		heading = sh,
		model = modelHash
	}

	spawnPlayerDirect(spawnTable)
end)

CreateThread(function()
	local opened = false
	while true do
		if NetworkIsSessionStarted() and not opened and not prejoinStarted then
			opened = true
			openPrejoinUi()
		end

		Wait(250)
	end
end)

CreateThread(function()
	while not NetworkIsSessionStarted() do
		clearLoadingScreenNow()
		Wait(0)
	end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	keepClearingLoadingScreen(60000, 0)
end)

CreateThread(function()
	while true do
		hideLoadingIndicators()

		if NetworkIsSessionStarted() then
			ShutdownLoadingScreen()

			if type(ShutdownLoadingScreenNui) == 'function' then
				ShutdownLoadingScreenNui()
			end

			Wait(persistentSpinnerGuardIntervalMs)
		else
			clearLoadingScreenNow()
			Wait(0)
		end
	end
end)

Citizen.CreateThread(function()
    while true do
        local ped = PlayerPedId()

        InvalidateIdleCam()
        InvalidateVehicleIdleCam()
        SetPedConfigFlag(ped, 35, false)
        SetPedConfigFlag(ped, 184, true)
        SetPedConfigFlag(ped, 366, false)

        if IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
			local manualSeatShuffleActive = manualDriverSeatShuffleVehicle == vehicle and GetGameTimer() < manualDriverSeatShuffleExpiresAt

            -- Block the manual seat-shuffle input.
            DisableControlAction(0, 104, true)

            -- If GTA starts the shuffle task from front passenger to driver, force the ped back.
			if GetPedInVehicleSeat(vehicle, 0) == ped and GetIsTaskActive(ped, 165) and not manualSeatShuffleActive then
                SetPedIntoVehicle(ped, vehicle, 0)
            end

			if manualDriverSeatShuffleVehicle ~= 0 then
				if manualDriverSeatShuffleVehicle ~= vehicle or GetGameTimer() >= manualDriverSeatShuffleExpiresAt or GetPedInVehicleSeat(vehicle, -1) == ped then
					manualDriverSeatShuffleVehicle = 0
					manualDriverSeatShuffleExpiresAt = 0
				end
			end

            Wait(0)
        else
			if manualDriverSeatShuffleVehicle ~= 0 then
				manualDriverSeatShuffleVehicle = 0
				manualDriverSeatShuffleExpiresAt = 0
			end

            Wait(250)
        end
    end
end)