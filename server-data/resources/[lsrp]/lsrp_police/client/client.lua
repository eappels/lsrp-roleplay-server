local stationBlips = {}
local assignedPatrolVehicle = nil
local patrolVehicleSpawnInProgress = false
local OWNED_VEHICLE_ID_STATE_KEY = 'lsrpOwnedVehicleId'

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

local function notify(message)
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

local function isPoliceEmployee()
	local playerState = LocalPlayer and LocalPlayer.state
	return playerState and playerState.lsrp_job == Config.JobId or false
end

local function isPoliceOnDuty()
	local playerState = LocalPlayer and LocalPlayer.state
	return playerState and playerState.lsrp_job == Config.JobId and playerState.lsrp_job_duty == true or false
end

local function destroyStationBlips()
	for _, blip in ipairs(stationBlips) do
		RemoveBlip(blip)
	end

	stationBlips = {}
end

local function createStationBlips()
	destroyStationBlips()

	for _, station in ipairs(Config.Stations or {}) do
		local blipConfig = station.blip
		if blipConfig and blipConfig.enabled ~= false then
			local blip = AddBlipForCoord(station.dutyCoords.x, station.dutyCoords.y, station.dutyCoords.z)
			SetBlipSprite(blip, math.floor(tonumber(blipConfig.sprite) or 60))
			SetBlipDisplay(blip, 4)
			SetBlipScale(blip, tonumber(blipConfig.scale) or 0.82)
			SetBlipColour(blip, math.floor(tonumber(blipConfig.color) or 38))
			SetBlipAsShortRange(blip, true)
			BeginTextCommandSetBlipName('STRING')
			AddTextComponentSubstringPlayerName(trimString(blipConfig.label) or trimString(station.label) or 'Police Station')
			EndTextCommandSetBlipName(blip)
			stationBlips[#stationBlips + 1] = blip
		end
	end
end

local function ensurePatrolVehicleDeleted()
	if assignedPatrolVehicle and DoesEntityExist(assignedPatrolVehicle) then
		SetEntityAsMissionEntity(assignedPatrolVehicle, true, true)
		DeleteVehicle(assignedPatrolVehicle)
	end

	assignedPatrolVehicle = nil
	patrolVehicleSpawnInProgress = false
end

local function loadVehicleModel(modelName)
	local modelHash = GetHashKey(modelName)
	if not IsModelInCdimage(modelHash) or not IsModelAVehicle(modelHash) then
		return nil
	end

	RequestModel(modelHash)
	local timeoutAt = GetGameTimer() + 8000
	while not HasModelLoaded(modelHash) and GetGameTimer() < timeoutAt do
		Wait(0)
	end

	if not HasModelLoaded(modelHash) then
		return nil
	end

	return modelHash
end

local function preparePatrolVehicle(vehicle)
	if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
		return
	end

	SetVehicleDoorsLocked(vehicle, 1)
	SetVehicleDoorsLockedForAllPlayers(vehicle, false)
	SetVehicleNeedsToBeHotwired(vehicle, false)
	SetVehicleEngineOn(vehicle, false, true, true)
	SetVehicleDirtLevel(vehicle, 0.0)
	SetVehicleExtraColours(vehicle, 0, 0)
	local vehicleColors = type(Config.VehicleColors) == 'table' and Config.VehicleColors or {}
	SetVehicleColours(
		vehicle,
		math.floor(tonumber(vehicleColors.primary) or 111),
		math.floor(tonumber(vehicleColors.secondary) or 111)
	)
	SetVehicleOnGroundProperly(vehicle)

	local entityState = Entity(vehicle).state
	local localStateId = tonumber(LocalPlayer and LocalPlayer.state and LocalPlayer.state.state_id)
	if entityState then
		entityState:set('lsrpVehicleLocked', false, true)
		if localStateId and localStateId > 0 then
			entityState:set('lsrpVehicleOwnerStateId', localStateId, true)
		end
	end
end

local function requestEntityControl(entity)
	if not entity or entity == 0 or not DoesEntityExist(entity) then
		return false
	end

	if NetworkHasControlOfEntity(entity) then
		return true
	end

	NetworkRequestControlOfEntity(entity)
	local timeoutAt = GetGameTimer() + 1500
	while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeoutAt do
		Wait(0)
		NetworkRequestControlOfEntity(entity)
	end

	return NetworkHasControlOfEntity(entity)
end

local function deleteVehicleByNetId(netId)
	local normalizedNetId = tonumber(netId)
	if not normalizedNetId or normalizedNetId <= 0 or not NetworkDoesNetworkIdExist(normalizedNetId) then
		return false
	end

	local vehicle = NetToVeh(normalizedNetId)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return false
	end

	if not requestEntityControl(vehicle) then
		return false
	end

	SetEntityAsMissionEntity(vehicle, true, true)
	DeleteVehicle(vehicle)
	if DoesEntityExist(vehicle) then
		DeleteEntity(vehicle)
	end

	return not DoesEntityExist(vehicle)
end

local function getOwnedVehicleId(vehicle)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return nil
	end

	local entityState = Entity(vehicle).state
	if not entityState then
		return nil
	end

	local ownedVehicleId = tonumber(entityState[OWNED_VEHICLE_ID_STATE_KEY])
	if not ownedVehicleId or ownedVehicleId <= 0 then
		return nil
	end

	return ownedVehicleId
end

local function getVehicleProperties(vehicle)
	if not DoesEntityExist(vehicle) then
		return nil
	end

	local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
	local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)
	local extras = {}

	for extraId = 0, 12 do
		if DoesExtraExist(vehicle, extraId) then
			extras[tostring(extraId)] = IsVehicleExtraTurnedOn(vehicle, extraId)
		end
	end

	local doorsBroken, windowsBroken = {}, {}
	local tyreBurst = {}

	for i = 0, 5 do
		doorsBroken[i] = IsVehicleDoorDamaged(vehicle, i)
		windowsBroken[i] = not IsVehicleWindowIntact(vehicle, i)
	end

	for i = 0, 7 do
		tyreBurst[i] = IsVehicleTyreBurst(vehicle, i, false)
	end

	return {
		model = GetEntityModel(vehicle),
		pearlescentColor = pearlescentColor,
		wheelColor = wheelColor,
		color1 = colorPrimary,
		color2 = colorSecondary,
		customPrimaryColor = { GetVehicleCustomPrimaryColour(vehicle) },
		customSecondaryColor = { GetVehicleCustomSecondaryColour(vehicle) },
		paintType1 = GetVehicleModColor_1(vehicle),
		paintType2 = GetVehicleModColor_2(vehicle),
		plate = GetVehicleNumberPlateText(vehicle),
		plateIndex = GetVehicleNumberPlateTextIndex(vehicle),
		bodyHealth = GetVehicleBodyHealth(vehicle),
		engineHealth = GetVehicleEngineHealth(vehicle),
		tankHealth = GetVehiclePetrolTankHealth(vehicle),
		fuelLevel = GetVehicleFuelLevel(vehicle),
		dirtLevel = GetVehicleDirtLevel(vehicle),
		oilLevel = GetVehicleOilLevel(vehicle),
		doorsBroken = doorsBroken,
		windowsBroken = windowsBroken,
		tyreBurst = tyreBurst,
		modSpoilers = GetVehicleMod(vehicle, 0),
		modFrontBumper = GetVehicleMod(vehicle, 1),
		modRearBumper = GetVehicleMod(vehicle, 2),
		modSideSkirt = GetVehicleMod(vehicle, 3),
		modExhaust = GetVehicleMod(vehicle, 4),
		modFrame = GetVehicleMod(vehicle, 5),
		modGrille = GetVehicleMod(vehicle, 6),
		modHood = GetVehicleMod(vehicle, 7),
		modFender = GetVehicleMod(vehicle, 8),
		modRightFender = GetVehicleMod(vehicle, 9),
		modRoof = GetVehicleMod(vehicle, 10),
		modEngine = GetVehicleMod(vehicle, 11),
		modBrakes = GetVehicleMod(vehicle, 12),
		modTransmission = GetVehicleMod(vehicle, 13),
		modHorns = GetVehicleMod(vehicle, 14),
		modSuspension = GetVehicleMod(vehicle, 15),
		modArmor = GetVehicleMod(vehicle, 16),
		modTurbo = IsToggleModOn(vehicle, 18),
		modSmokeEnabled = IsToggleModOn(vehicle, 20),
		modXenon = IsToggleModOn(vehicle, 22),
		modFrontWheels = GetVehicleMod(vehicle, 23),
		modBackWheels = GetVehicleMod(vehicle, 24),
		modPlateHolder = GetVehicleMod(vehicle, 25),
		modVanityPlate = GetVehicleMod(vehicle, 26),
		modTrimA = GetVehicleMod(vehicle, 27),
		modOrnaments = GetVehicleMod(vehicle, 28),
		modDashboard = GetVehicleMod(vehicle, 29),
		modDial = GetVehicleMod(vehicle, 30),
		modDoorSpeaker = GetVehicleMod(vehicle, 31),
		modSeats = GetVehicleMod(vehicle, 32),
		modSteeringWheel = GetVehicleMod(vehicle, 33),
		modShifterLeavers = GetVehicleMod(vehicle, 34),
		modAPlate = GetVehicleMod(vehicle, 35),
		modSpeakers = GetVehicleMod(vehicle, 36),
		modTrunk = GetVehicleMod(vehicle, 37),
		modHydrolic = GetVehicleMod(vehicle, 38),
		modEngineBlock = GetVehicleMod(vehicle, 39),
		modAirFilter = GetVehicleMod(vehicle, 40),
		modStruts = GetVehicleMod(vehicle, 41),
		modArchCover = GetVehicleMod(vehicle, 42),
		modAerials = GetVehicleMod(vehicle, 43),
		modTrimB = GetVehicleMod(vehicle, 44),
		modTank = GetVehicleMod(vehicle, 45),
		modWindows = GetVehicleMod(vehicle, 46),
		modLivery = GetVehicleMod(vehicle, 48),
		wheelType = GetVehicleWheelType(vehicle),
		modCustomTiresF = GetVehicleModVariation(vehicle, 23),
		modCustomTiresR = GetVehicleModVariation(vehicle, 24),
		neonEnabled = {
			IsVehicleNeonLightEnabled(vehicle, 0),
			IsVehicleNeonLightEnabled(vehicle, 1),
			IsVehicleNeonLightEnabled(vehicle, 2),
			IsVehicleNeonLightEnabled(vehicle, 3)
		},
		neonColor = { GetVehicleNeonLightsColour(vehicle) },
		tyreSmokeColor = { GetVehicleTyreSmokeColor(vehicle) },
		windowTint = GetVehicleWindowTint(vehicle),
		extras = extras
	}
end

local function isVehicleOccupied(vehicle)
	local maxPassengers = GetVehicleMaxNumberOfPassengers(vehicle)
	for seatIndex = -1, maxPassengers do
		local ped = GetPedInVehicleSeat(vehicle, seatIndex)
		if ped and ped ~= 0 then
			return true
		end
	end

	return false
end

local function getCameraDirection()
	local rot = GetGameplayCamRot(0)
	local pitch = math.rad(rot.x)
	local heading = math.rad(rot.z)

	local x = -math.sin(heading) * math.cos(pitch)
	local y = math.cos(heading) * math.cos(pitch)
	local z = math.sin(pitch)

	return vector3(x, y, z)
end

local function clampNumber(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

local function getVehicleBoundsDistance(vehicle, worldPoint)
	if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
		return math.huge
	end

	local minimum, maximum = GetModelDimensions(GetEntityModel(vehicle))
	local localPoint = GetOffsetFromEntityGivenWorldCoords(vehicle, worldPoint.x, worldPoint.y, worldPoint.z)
	local closestWorld = GetOffsetFromEntityInWorldCoords(
		vehicle,
		clampNumber(localPoint.x, minimum.x, maximum.x),
		clampNumber(localPoint.y, minimum.y, maximum.y),
		clampNumber(localPoint.z, minimum.z, maximum.z)
	)

	return #(closestWorld - worldPoint)
end

local function getForwardProbePoint(playerPed, distance)
	local playerCoords = GetEntityCoords(playerPed)
	local forwardVector = GetEntityForwardVector(playerPed)
	return vector3(
		playerCoords.x + (forwardVector.x * distance),
		playerCoords.y + (forwardVector.y * distance),
		playerCoords.z + 0.25
	)
end

local function getDistanceToVehicleBounds(vehicle, worldPoint)
	return getVehicleBoundsDistance(vehicle, worldPoint)
end

local function findVehiclePlayerIsFacing(maxDistance)
	local playerPed = PlayerPedId()
	local maxTargetDistance = tonumber(maxDistance) or 2.0
	local playerCoords = GetEntityCoords(playerPed)
	local forwardProbe = getForwardProbePoint(playerPed, math.min(1.8, math.max(1.0, maxTargetDistance)))
	local cameraOrigin = GetGameplayCamCoord()
	local cameraDirection = getCameraDirection()
	local rayTarget = cameraOrigin + (cameraDirection * math.max(maxTargetDistance + 5.0, 8.0))
	local rayHandle = StartShapeTestRay(cameraOrigin.x, cameraOrigin.y, cameraOrigin.z, rayTarget.x, rayTarget.y, rayTarget.z, 10, playerPed, 0)
	local _, hit, _, _, entityHit = GetShapeTestResult(rayHandle)

	if hit == 1 and entityHit and entityHit ~= 0 and DoesEntityExist(entityHit) and IsEntityAVehicle(entityHit) then
		local playerDistance = getDistanceToVehicleBounds(entityHit, playerCoords)
		local probeDistance = getDistanceToVehicleBounds(entityHit, forwardProbe)
		if math.min(playerDistance, probeDistance) <= (maxTargetDistance + 0.5) then
			return entityHit
		end
	end

	local bestVehicle = nil
	local bestScore = nil
	for _, vehicle in ipairs(GetGamePool('CVehicle')) do
		if vehicle ~= 0 and DoesEntityExist(vehicle) then
			local playerDistance = getDistanceToVehicleBounds(vehicle, playerCoords)
			local probeDistance = getDistanceToVehicleBounds(vehicle, forwardProbe)
			local nearestDistance = math.min(playerDistance, probeDistance)
			if nearestDistance <= (maxTargetDistance + 0.5) then
			local vehicleCoords = GetEntityCoords(vehicle)
			local directionToVehicle = vehicleCoords - cameraOrigin
			local length = #directionToVehicle
			if length > 0.001 then
				local normalizedDirection = directionToVehicle / length
				local dot = (cameraDirection.x * normalizedDirection.x) + (cameraDirection.y * normalizedDirection.y) + (cameraDirection.z * normalizedDirection.z)
				local score = (dot * 4.0) - nearestDistance
				if dot > 0.35 and (bestScore == nil or score > bestScore) then
					bestScore = score
					bestVehicle = vehicle
				end
			elseif bestScore == nil or (-nearestDistance) > bestScore then
				bestScore = -nearestDistance
				bestVehicle = vehicle
				end
			end
		end
	end

	return bestVehicle
end

local function impoundFacingVehicle()
	if not isPoliceEmployee() then
		notify('Only LSPD employees can use /impound.')
		return
	end

	if not isPoliceOnDuty() then
		notify('Clock in for police duty before using /impound.')
		return
	end

	local playerPed = PlayerPedId()
	if IsPedInAnyVehicle(playerPed, false) then
		notify('Exit your vehicle before using /impound.')
		return
	end

	local targetVehicle = findVehiclePlayerIsFacing(Config.ImpoundRange)
	if not targetVehicle then
		notify(('Face a vehicle within %.1f meters before using /impound.'):format(tonumber(Config.ImpoundRange) or 2.0))
		return
	end

	if assignedPatrolVehicle and targetVehicle == assignedPatrolVehicle then
		notify('You cannot impound your assigned patrol cruiser.')
		return
	end

	if isVehicleOccupied(targetVehicle) then
		notify('The target vehicle must be empty before it can be impounded.')
		return
	end

	local vehicleProps = getVehicleProperties(targetVehicle)
	if not vehicleProps then
		notify('The target vehicle could not be inspected for impound storage.')
		return
	end

	TriggerServerEvent('lsrp_police:server:impoundVehicle', {
		model = GetEntityModel(targetVehicle),
		plate = GetVehicleNumberPlateText(targetVehicle),
		props = vehicleProps,
		netId = VehToNet(targetVehicle),
		ownedVehicleId = getOwnedVehicleId(targetVehicle)
	})
end

local function spawnPatrolVehicle(station)
	if not station then
		return
	end

	if patrolVehicleSpawnInProgress then
		return
	end

	if assignedPatrolVehicle and DoesEntityExist(assignedPatrolVehicle) then
		notify('Return your current patrol vehicle before spawning another one.')
		return
	end

	local playerPed = PlayerPedId()
	if IsPedInAnyVehicle(playerPed, false) then
		notify('Exit your current vehicle before collecting a patrol cruiser.')
		return
	end

	patrolVehicleSpawnInProgress = true

	local modelHash = loadVehicleModel(Config.VehicleModel)
	if not modelHash then
		patrolVehicleSpawnInProgress = false
		notify('Patrol vehicle model could not be loaded.')
		return
	end

	local spawn = station.vehicleSpawn
	if not spawn or not spawn.coords then
		patrolVehicleSpawnInProgress = false
		SetModelAsNoLongerNeeded(modelHash)
		notify('Police garage spawn point is not configured correctly.')
		return
	end

	local vehicle = CreateVehicle(modelHash, spawn.coords.x, spawn.coords.y, spawn.coords.z, spawn.heading or 0.0, true, false)
	if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
		patrolVehicleSpawnInProgress = false
		SetModelAsNoLongerNeeded(modelHash)
		notify('Patrol vehicle could not be spawned. Make sure the garage bay is clear.')
		return
	end

	assignedPatrolVehicle = vehicle
	SetEntityAsMissionEntity(assignedPatrolVehicle, true, true)
	SetVehicleNumberPlateText(assignedPatrolVehicle, string.sub((Config.VehiclePlatePrefix or 'LSPD') .. tostring(GetPlayerServerId(PlayerId())), 1, 8))
	preparePatrolVehicle(assignedPatrolVehicle)
	TaskWarpPedIntoVehicle(playerPed, assignedPatrolVehicle, -1)
	SetModelAsNoLongerNeeded(modelHash)
	patrolVehicleSpawnInProgress = false
	notify('Patrol cruiser ready. Stay on duty while operating department vehicles.')
end

local function returnPatrolVehicle()
	if not assignedPatrolVehicle or not DoesEntityExist(assignedPatrolVehicle) then
		notify('No department patrol vehicle is currently assigned to you.')
		return
	end

	local playerPed = PlayerPedId()
	if GetVehiclePedIsIn(playerPed, false) ~= assignedPatrolVehicle then
		notify('Sit in your patrol vehicle before returning it.')
		return
	end

	ensurePatrolVehicleDeleted()
	notify('Patrol vehicle returned to the garage.')
end

local function openPoliceDressingRoom()
	if not isPoliceEmployee() then
		notify('Only sworn LSPD personnel can access the police dressing room.')
		return
	end

	TriggerEvent('lsrp_pededitor:open')
end

RegisterNetEvent('lsrp_police:client:notify', function(message)
	notify(message)
end)

RegisterNetEvent('lsrp_police:client:dutyResult', function(payload)
	payload = type(payload) == 'table' and payload or {}
	if payload.message then
		notify(payload.message)
	end
end)

RegisterNetEvent('lsrp_police:client:removeImpoundedVehicle', function(payload)
	payload = type(payload) == 'table' and payload or {}
	if deleteVehicleByNetId(payload.netId) then
		notify(payload.message or 'Unregistered vehicle removed from the roadway.')
		return
	end

	notify('The impounded vehicle could not be removed immediately.')
end)

RegisterNetEvent('lsrp_jobs:client:employmentUpdated', function()
	if not isPoliceEmployee() then
		ensurePatrolVehicleDeleted()
	end
end)

RegisterCommand(Config.ImpoundCommand or 'impound', function()
	impoundFacingVehicle()
end, false)

CreateThread(function()
	createStationBlips()

	while true do
		local waitMs = 750
		local playerPed = PlayerPedId()

		if playerPed ~= 0 and DoesEntityExist(playerPed) then
			local playerCoords = GetEntityCoords(playerPed)

			for _, station in ipairs(Config.Stations or {}) do
				local drawDistance = tonumber(Config.DrawDistance) or 30.0
				local interactionDistance = tonumber(Config.InteractionDistance) or 2.5
				local dutyDistance = #(playerCoords - station.dutyCoords)
				local dressingRoomDistance = station.dressingRoomCoords and #(playerCoords - station.dressingRoomCoords) or math.huge
				local spawnDistance = #(playerCoords - station.vehicleSpawn.coords)
				local returnDistance = #(playerCoords - station.vehicleReturn)

				if dutyDistance <= drawDistance or dressingRoomDistance <= drawDistance or spawnDistance <= drawDistance or returnDistance <= drawDistance then
					waitMs = 0
				end

				if dutyDistance <= drawDistance then
					DrawMarker(1, station.dutyCoords.x, station.dutyCoords.y, station.dutyCoords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.65, 1.65, 0.7, 82, 162, 255, 110, false, false, 2, false, nil, nil, false)
				end

				if dressingRoomDistance <= drawDistance then
					DrawMarker(1, station.dressingRoomCoords.x, station.dressingRoomCoords.y, station.dressingRoomCoords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.35, 1.35, 0.55, 82, 162, 255, 110, false, false, 2, false, nil, nil, false)
				end

				if spawnDistance <= drawDistance then
					DrawMarker(36, station.vehicleSpawn.coords.x, station.vehicleSpawn.coords.y, station.vehicleSpawn.coords.z + 0.45, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.55, 0.55, 0.55, 82, 162, 255, 150, false, false, 2, false, nil, nil, false)
				end

				if returnDistance <= drawDistance then
					DrawMarker(1, station.vehicleReturn.x, station.vehicleReturn.y, station.vehicleReturn.z - 1.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.2, 2.2, 0.8, 222, 107, 94, 110, false, false, 2, false, nil, nil, false)
				end

				if isPoliceEmployee() and dutyDistance <= interactionDistance then
					if isPoliceOnDuty() then
						showHelpPrompt('Press ~INPUT_CONTEXT~ to clock out of police duty')
						if isInteractionJustPressed() then
							if assignedPatrolVehicle and DoesEntityExist(assignedPatrolVehicle) then
								notify('Return your patrol vehicle before clocking out.')
							else
								TriggerServerEvent('lsrp_police:server:toggleDuty', false)
							end
							Wait(300)
						end
					else
						showHelpPrompt('Press ~INPUT_CONTEXT~ to clock in for police duty')
						if isInteractionJustPressed() then
							TriggerServerEvent('lsrp_police:server:toggleDuty', true)
							Wait(300)
						end
					end
				elseif dutyDistance <= interactionDistance then
					showHelpPrompt('Only sworn LSPD personnel can access the duty locker')
					if isInteractionJustPressed() then
						notify('You are not assigned to the Los Santos Police Department.')
						Wait(300)
					end
				end

				if isPoliceEmployee() and dressingRoomDistance <= interactionDistance then
					showHelpPrompt(Config.DressingRoomPrompt or 'Press ~INPUT_CONTEXT~ to access the police dressing room')
					if isInteractionJustPressed() then
						openPoliceDressingRoom()
						Wait(300)
					end
				elseif dressingRoomDistance <= interactionDistance then
					showHelpPrompt('Only sworn LSPD personnel can access the police dressing room')
					if isInteractionJustPressed() then
						notify('You are not assigned to the Los Santos Police Department.')
						Wait(300)
					end
				end

				if isPoliceOnDuty() and spawnDistance <= interactionDistance then
					showHelpPrompt('Press ~INPUT_CONTEXT~ to collect a patrol cruiser')
					if isInteractionJustPressed() then
						spawnPatrolVehicle(station)
						Wait(300)
					end
				elseif isPoliceEmployee() and spawnDistance <= interactionDistance then
					showHelpPrompt('Clock in for duty before using the police garage')
				elseif spawnDistance <= interactionDistance then
					showHelpPrompt('Police garage access is restricted to sworn personnel')
				end

				if returnDistance <= interactionDistance then
					showHelpPrompt('Press ~INPUT_CONTEXT~ to return your patrol vehicle')
					if isInteractionJustPressed() then
						returnPatrolVehicle()
						Wait(300)
					end
				end
			end
		end

		Wait(waitMs)
	end
end)

CreateThread(function()
	while true do
		if assignedPatrolVehicle and not DoesEntityExist(assignedPatrolVehicle) then
			assignedPatrolVehicle = nil
			patrolVehicleSpawnInProgress = false
		end

		Wait(1000)
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		destroyStationBlips()
		ensurePatrolVehicleDeleted()
	end
end)