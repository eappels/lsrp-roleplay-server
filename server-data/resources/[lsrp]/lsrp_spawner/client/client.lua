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
local manualDriverSeatShuffleVehicle = 0
local manualDriverSeatShuffleExpiresAt = 0

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

AddEventHandler('gameEventTriggered', function (name)
	if name == 'CEventNetworkStartMatch' then
		keepClearingLoadingScreen(60000, 0)
		TriggerServerEvent('lsrp_spawner:requestSpawn')
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

-- ---------------------------------------------------------------------------
-- Spawn helpers
-- ---------------------------------------------------------------------------

-- Freezes or unfreezes the local player (control, visibility, collision, invincibility).
local function freezeLocalPlayer(freeze)
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
local function spawnPlayerDirect(spawn)
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
	TriggerServerEvent('lsrp_core:savePosition', {
		x = spawnX,
		y = spawnY,
		z = spawnZ,
		heading = spawnHeading
	})

	TriggerEvent('playerSpawned', spawn)
end

exports('spawnPlayerDirect', spawnPlayerDirect)

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