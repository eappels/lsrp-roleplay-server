-- LSRP Testing - Client Script
--
-- Spawns a single military guard NPC that patrols a configurable BoxZone area.
-- When the local player enters the guard zone the NPC engages in combat;
-- when the player leaves, the NPC returns to its post.
--
-- Configuration is loaded from shared/config.lua at startup and can be reloaded
-- at runtime with the /lsrptest_reloadzones command.
--
-- Dependencies: polyzone (BoxZone)
--
-- Commands:
--   /lsrptest_reloadzones - hot-reload patrol zone config without restarting

local pedConfig = {
	model = `s_m_y_marine_01`,
	x = -2304.17,
	y = 3383.12,
	z = 31.02,
	heading = 50.66
}

local GUARD_WEAPON = `WEAPON_ASSAULTRIFLE_MK2`
local GUARD_RADIUS = 20.0
local GUARD_REPOSITION_DISTANCE = 35.0
local GUARD_CHECK_INTERVAL_MS = 4000
local CONFIG_FILE_PATH = 'shared/config.lua'
local DEFAULT_GUARD_ZONE_NAME = 'patrol_zancudo_west'

local spawnedPed = nil
local patrolZones = {}
local hasInitialized = false
local guardZoneName = DEFAULT_GUARD_ZONE_NAME
local guardZoneRef = nil
local playerInsideGuardZone = false
local guardTarget = {
	x = pedConfig.x,
	y = pedConfig.y,
	z = pedConfig.z,
	heading = pedConfig.heading,
	radius = GUARD_RADIUS,
	repositionDistance = GUARD_REPOSITION_DISTANCE
}

local function resetGuardTargetToDefault()
	guardTarget.x = pedConfig.x
	guardTarget.y = pedConfig.y
	guardTarget.z = pedConfig.z
	guardTarget.heading = pedConfig.heading
	guardTarget.radius = GUARD_RADIUS
	guardTarget.repositionDistance = GUARD_REPOSITION_DISTANCE
end

-- ---------------------------------------------------------------------------
-- Guard zone helpers
-- ---------------------------------------------------------------------------

-- Updates guardTarget with the zone's center/size so the guard patrols the
-- correct area when the zone config changes.
local function setGuardTargetFromZone(centerX, centerY, centerZ, heading, sizeX, sizeY)
	local zoneRadius = math.max(sizeX, sizeY) * 0.5
	zoneRadius = math.max(5.0, math.min(zoneRadius, 80.0))

	guardTarget.x = centerX
	guardTarget.y = centerY
	guardTarget.z = centerZ
	guardTarget.heading = heading
	guardTarget.radius = zoneRadius
	guardTarget.repositionDistance = math.max(zoneRadius + 10.0, zoneRadius * 1.75)
end

local function showGuardNotification(message)
	BeginTextCommandThefeedPost('STRING')
	AddTextComponentSubstringPlayerName(message)
	EndTextCommandThefeedPostTicker(false, false)
end

local function engageGuardWithPlayer(ped)
	if not ped or ped == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) then
		return
	end

	local playerPed = PlayerPedId()
	if not playerPed or playerPed == 0 or IsEntityDead(playerPed) then
		return
	end

	SetPedKeepTask(ped, true)
	SetPedAsEnemy(ped, true)
	TaskCombatPed(ped, playerPed, 0, 16)
end

-- Registers an onPlayerInOut callback on the given zone so the guard reacts
-- to the player entering or leaving the patrol area.
local function setupGuardZoneWatcher(zone)
	if not zone or type(zone.onPlayerInOut) ~= 'function' then
		return
	end

	zone:onPlayerInOut(function(isInside)
		playerInsideGuardZone = isInside == true

		if not spawnedPed or not DoesEntityExist(spawnedPed) or IsEntityDead(spawnedPed) then
			return
		end

		if playerInsideGuardZone then
			showGuardNotification('~r~Restricted military zone: leave immediately!')
			engageGuardWithPlayer(spawnedPed)
			return
		end

		ClearPedTasks(spawnedPed)
		TaskGoStraightToCoord(spawnedPed, guardTarget.x, guardTarget.y, guardTarget.z, 1.5, -1, guardTarget.heading, 0.0)
		SetPedKeepTask(spawnedPed, true)
	end, 200)
end

-- Loads lsrpTestingConfig from shared/config.lua using LoadResourceFile, so
-- changes can be picked up without a full resource restart.
local function loadTestingConfigFromFile()
	if type(LoadResourceFile) ~= 'function' then
		return false
	end

	local rawConfig = LoadResourceFile(GetCurrentResourceName(), CONFIG_FILE_PATH)
	if type(rawConfig) ~= 'string' or rawConfig == '' then
		return false
	end

	local env = {}
	local chunk, compileErr = load(rawConfig, '@lsrp_testing/' .. CONFIG_FILE_PATH, 't', env)
	if not chunk then
		print(('[lsrp_testing] Config compile error: %s'):format(tostring(compileErr)))
		return false
	end

	local ok, runtimeErr = pcall(chunk)
	if not ok then
		print(('[lsrp_testing] Config runtime error: %s'):format(tostring(runtimeErr)))
		return false
	end

	if type(env.lsrpTestingConfig) ~= 'table' then
		print('[lsrp_testing] shared/config.lua must define lsrpTestingConfig as a table.')
		return false
	end

	lsrpTestingConfig = env.lsrpTestingConfig
	return true
end

local function destroyPatrolZones()
	for i = 1, #patrolZones do
		local zone = patrolZones[i]
		if zone and type(zone.destroy) == 'function' then
			zone:destroy()
		end
	end

	patrolZones = {}
end

-- ---------------------------------------------------------------------------
-- BoxZone setup
-- ---------------------------------------------------------------------------

-- (Re)creates all configured patrol BoxZones from lsrpTestingConfig.
local function createPatrolZonesFromConfig()
	destroyPatrolZones()

	if type(BoxZone) ~= 'table' or type(BoxZone.Create) ~= 'function' then
		print('[lsrp_testing] BoxZone is not available. Ensure polyzone is started and imported in fxmanifest.')
		return
	end

	local cfg = lsrpTestingConfig or {}
	local zones = type(cfg.patrolZones) == 'table' and cfg.patrolZones or {}
	local showDebug = cfg.showPatrolZoneDebug == true
	guardZoneName = type(cfg.guardZoneName) == 'string' and cfg.guardZoneName or DEFAULT_GUARD_ZONE_NAME
	resetGuardTargetToDefault()
	guardZoneRef = nil
	playerInsideGuardZone = false

	local foundGuardZone = false

	for index, zoneCfg in ipairs(zones) do
		local center = type(zoneCfg.center) == 'table' and zoneCfg.center or {}
		local size = type(zoneCfg.size) == 'table' and zoneCfg.size or {}
		local zoneName = type(zoneCfg.name) == 'string' and zoneCfg.name or ('lsrp_testing_patrol_' .. index)

		local centerX = tonumber(center.x)
		local centerY = tonumber(center.y)
		local centerZ = tonumber(center.z)

		if centerX and centerY and centerZ then
			local sizeX = math.max(0.1, tonumber(size.x) or 1.0)
			local sizeY = math.max(0.1, tonumber(size.y) or 1.0)
			local sizeZ = math.max(0.1, tonumber(size.z) or 3.0)
			local heading = tonumber(zoneCfg.heading) or 0.0

			local zone = BoxZone:Create(vector3(centerX, centerY, centerZ), sizeX, sizeY, {
				name = zoneName,
				heading = heading,
				minZ = centerZ - (sizeZ / 2.0),
				maxZ = centerZ + (sizeZ / 2.0),
				debugPoly = showDebug
			})

			patrolZones[#patrolZones + 1] = zone
			print(('[lsrp_testing] Zone %s size updated to x=%.2f y=%.2f z=%.2f'):format(zoneName, sizeX, sizeY, sizeZ))

			if zoneName == guardZoneName then
				setGuardTargetFromZone(centerX, centerY, centerZ, heading, sizeX, sizeY)
				guardZoneRef = zone
				foundGuardZone = true
			end
		else
			print(('[lsrp_testing] Invalid patrol zone config at index %s'):format(index))
		end
	end

	if foundGuardZone then
		print(('[lsrp_testing] Guard zone set to %s'):format(guardZoneName))
		setupGuardZoneWatcher(guardZoneRef)
	else
		print(('[lsrp_testing] Guard zone %s not found. Using default ped coordinates.'):format(guardZoneName))
	end
end

-- ---------------------------------------------------------------------------
-- Guard NPC
-- ---------------------------------------------------------------------------

-- Assigns a stationary guard task to the ped with the given patrol radius.
local function assignGuardTask(ped, radius)
	if not ped or ped == 0 or not DoesEntityExist(ped) then
		return
	end

	local guardRadius = tonumber(radius) or GUARD_RADIUS
	SetPedKeepTask(ped, true)
	TaskGuardCurrentPosition(ped, guardRadius, guardRadius, true)
end

local function loadModel(model)
	if HasModelLoaded(model) then
		return true
	end

	RequestModel(model)
	local timeoutAt = GetGameTimer() + 10000

	while not HasModelLoaded(model) do
		if GetGameTimer() > timeoutAt then
			return false
		end

		Wait(0)
	end

	return true
end

-- Spawns the military ped at the current guardTarget position and arms it.
local function createMilitaryPed()
	if spawnedPed and DoesEntityExist(spawnedPed) then
		return
	end

	if not loadModel(pedConfig.model) then
		print('[lsrp_testing] Failed to load military ped model.')
		return
	end

	spawnedPed = CreatePed(4, pedConfig.model, guardTarget.x, guardTarget.y, guardTarget.z - 1.0, guardTarget.heading, false, false)

	if not spawnedPed or spawnedPed == 0 then
		print('[lsrp_testing] Failed to create military ped.')
		return
	end

	SetEntityAsMissionEntity(spawnedPed, true, true)
	SetEntityHeading(spawnedPed, guardTarget.heading)
	SetEntityCoordsNoOffset(spawnedPed, guardTarget.x, guardTarget.y, guardTarget.z, false, false, false)
	SetBlockingOfNonTemporaryEvents(spawnedPed, true)
	SetPedCanRagdoll(spawnedPed, false)
	SetPedFleeAttributes(spawnedPed, 0, false)
	SetPedArmour(spawnedPed, 100)
	SetPedAccuracy(spawnedPed, 65)
	SetPedAlertness(spawnedPed, 3)
	SetPedSeeingRange(spawnedPed, 100.0)
	SetPedHearingRange(spawnedPed, 100.0)
	SetPedCombatAbility(spawnedPed, 2)
	SetPedCombatRange(spawnedPed, 2)
	SetPedCombatMovement(spawnedPed, 1)
	SetPedCombatAttributes(spawnedPed, 46, true)

	GiveWeaponToPed(spawnedPed, GUARD_WEAPON, 9999, false, true)
	SetCurrentPedWeapon(spawnedPed, GUARD_WEAPON, true)
	SetPedAmmo(spawnedPed, GUARD_WEAPON, 9999)
	SetPedInfiniteAmmo(spawnedPed, true, GUARD_WEAPON)
	assignGuardTask(spawnedPed, guardTarget.radius)

	if playerInsideGuardZone then
		engageGuardWithPlayer(spawnedPed)
	end

	SetModelAsNoLongerNeeded(pedConfig.model)
end

local function initializeTestingResource(forceRebuild)
	if hasInitialized and not forceRebuild then
		return
	end

	hasInitialized = true
	loadTestingConfigFromFile()
	createPatrolZonesFromConfig()

	if not spawnedPed or not DoesEntityExist(spawnedPed) then
		Wait(500)
		createMilitaryPed()
	end
end

CreateThread(function()
	initializeTestingResource(false)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	initializeTestingResource(true)
end)

CreateThread(function()
	while true do
		Wait(GUARD_CHECK_INTERVAL_MS)

		if spawnedPed and DoesEntityExist(spawnedPed) and not IsEntityDead(spawnedPed) then
			if not IsPedInCombat(spawnedPed, 0) then
				local guardPost = vector3(guardTarget.x, guardTarget.y, guardTarget.z)
				local guardHeading = guardTarget.heading
				local repositionDistance = guardTarget.repositionDistance
				local pedCoords = GetEntityCoords(spawnedPed)
				local distance = #(pedCoords - guardPost)

				if distance > repositionDistance then
					TaskGoStraightToCoord(spawnedPed, guardTarget.x, guardTarget.y, guardTarget.z, 1.5, -1, guardHeading, 0.0)
					SetPedKeepTask(spawnedPed, true)
				else
					SetEntityHeading(spawnedPed, guardHeading)
					assignGuardTask(spawnedPed, guardTarget.radius)
				end
			end
		end
	end
end)

local function cleanupTestingResource(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	if spawnedPed and DoesEntityExist(spawnedPed) then
		DeleteEntity(spawnedPed)
		spawnedPed = nil
	end

	hasInitialized = false
	guardZoneRef = nil
	playerInsideGuardZone = false
	destroyPatrolZones()
end

AddEventHandler('onResourceStop', cleanupTestingResource)
AddEventHandler('onClientResourceStop', cleanupTestingResource)

RegisterCommand('lsrptest_reloadzones', function()
	loadTestingConfigFromFile()
	createPatrolZonesFromConfig()
	print('[lsrp_testing] Patrol zones manually reloaded from config.')
end, false)
