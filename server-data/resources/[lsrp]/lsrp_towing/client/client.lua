local depotBlips = {}
local assignedTowTruck = nil
local towTruckSpawnInProgress = false
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
	if GetResourceState('lsrp_framework') == 'started' then
		exports['lsrp_framework']:notify(message, 'info')
		return
	end

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

local function isTowEmployee()
	local playerState = LocalPlayer and LocalPlayer.state
	return playerState and playerState.lsrp_job == Config.JobId or false
end

local function isTowOnDuty()
	local playerState = LocalPlayer and LocalPlayer.state
	return playerState and playerState.lsrp_job == Config.JobId and playerState.lsrp_job_duty == true or false
end

local function destroyDepotBlips()
	for _, blip in ipairs(depotBlips) do
		RemoveBlip(blip)
	end

	depotBlips = {}
end

local function createDepotBlips()
	destroyDepotBlips()

	for _, depot in ipairs(Config.Depots or {}) do
		local blipConfig = depot.blip
		if blipConfig and blipConfig.enabled ~= false then
			local blip = AddBlipForCoord(depot.dutyCoords.x, depot.dutyCoords.y, depot.dutyCoords.z)
			SetBlipSprite(blip, math.floor(tonumber(blipConfig.sprite) or 68))
			SetBlipDisplay(blip, 4)
			SetBlipScale(blip, tonumber(blipConfig.scale) or 0.85)
			SetBlipColour(blip, math.floor(tonumber(blipConfig.color) or 17))
			SetBlipAsShortRange(blip, true)
			BeginTextCommandSetBlipName('STRING')
			AddTextComponentSubstringPlayerName(trimString(blipConfig.label) or trimString(depot.label) or 'Tow Yard')
			EndTextCommandSetBlipName(blip)
			depotBlips[#depotBlips + 1] = blip
		end
	end
end

local function ensureTowTruckDeleted()
	if assignedTowTruck and DoesEntityExist(assignedTowTruck) then
		SetEntityAsMissionEntity(assignedTowTruck, true, true)
		DeleteVehicle(assignedTowTruck)
	end

	assignedTowTruck = nil
	towTruckSpawnInProgress = false
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

local function prepareCompanyTowTruck(vehicle)
	if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
		return
	end

	SetVehicleDoorsLocked(vehicle, 1)
	SetVehicleDoorsLockedForAllPlayers(vehicle, false)
	SetVehicleNeedsToBeHotwired(vehicle, false)
	SetVehicleEngineOn(vehicle, false, true, true)
	SetVehicleDirtLevel(vehicle, 0.0)
	SetVehicleExtraColours(vehicle, 0, 0)
	SetVehicleColours(vehicle, 111, 111)
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

local function getDistanceToVehicleBounds(vehicle, worldPoint)
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

local function findVehiclePlayerIsFacing(maxDistance)
	local playerPed = PlayerPedId()
	local maxTargetDistance = tonumber(maxDistance) or 2.0
	local playerCoords = GetEntityCoords(playerPed)
	local cameraOrigin = GetGameplayCamCoord()
	local cameraDirection = getCameraDirection()
	local rayTarget = cameraOrigin + (cameraDirection * math.max(maxTargetDistance + 5.0, 8.0))
	local rayHandle = StartShapeTestRay(cameraOrigin.x, cameraOrigin.y, cameraOrigin.z, rayTarget.x, rayTarget.y, rayTarget.z, 10, playerPed, 0)
	local _, hit, _, _, entityHit = GetShapeTestResult(rayHandle)

	if hit == 1 and entityHit and entityHit ~= 0 and DoesEntityExist(entityHit) and IsEntityAVehicle(entityHit) then
		if getDistanceToVehicleBounds(entityHit, playerCoords) <= (maxTargetDistance + 0.25) then
			return entityHit
		end
	end

	local bestVehicle = nil
	local bestDot = -1.0
	for _, vehicle in ipairs(GetGamePool('CVehicle')) do
		if vehicle ~= 0 and DoesEntityExist(vehicle) and getDistanceToVehicleBounds(vehicle, playerCoords) <= (maxTargetDistance + 0.25) then
			local vehicleCoords = GetEntityCoords(vehicle)
			local directionToVehicle = vehicleCoords - cameraOrigin
			local length = #directionToVehicle
			if length > 0.001 then
				local normalizedDirection = directionToVehicle / length
				local dot = (cameraDirection.x * normalizedDirection.x) + (cameraDirection.y * normalizedDirection.y) + (cameraDirection.z * normalizedDirection.z)
				if dot > 0.7 and dot > bestDot then
					bestDot = dot
					bestVehicle = vehicle
				end
			end
		end
	end

	return bestVehicle
end

local function impoundFacingVehicle()
	if not isTowEmployee() then
		notify('Only LS Recovery & Tow employees can use /impound.')
		return
	end

	if not isTowOnDuty() then
		notify('Clock in for tow duty before using /impound.')
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

	if assignedTowTruck and targetVehicle == assignedTowTruck then
		notify('You cannot impound your assigned company tow truck.')
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

	TriggerServerEvent('lsrp_towing:server:impoundVehicle', {
		model = GetEntityModel(targetVehicle),
		plate = GetVehicleNumberPlateText(targetVehicle),
		props = vehicleProps,
		netId = VehToNet(targetVehicle),
		ownedVehicleId = getOwnedVehicleId(targetVehicle)
	})
end

local function getAttachedVehicle(towTruck)
	if not towTruck or towTruck == 0 or not DoesEntityExist(towTruck) then
		return nil
	end

	for _, vehicle in ipairs(GetGamePool('CVehicle')) do
		if vehicle ~= towTruck and DoesEntityExist(vehicle) and IsEntityAttachedToEntity(vehicle, towTruck) then
			return vehicle
		end
	end

	return nil
end

local function isTowableVehicle(vehicle)
	if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
		return false
	end

	local model = GetEntityModel(vehicle)
	if not IsModelAVehicle(model) then
		return false
	end

	if model == GetHashKey(Config.VehicleModel) then
		return false
	end

	if IsThisModelAHeli(model) or IsThisModelAPlane(model) or IsThisModelABoat(model) or IsThisModelATrain(model) then
		return false
	end

	return true
end

local function findTowCandidate(towTruck)
	local towTruckCoords = GetEntityCoords(towTruck)
	local bestVehicle = nil
	local bestDistance = math.huge

	for _, vehicle in ipairs(GetGamePool('CVehicle')) do
		if vehicle ~= towTruck and DoesEntityExist(vehicle) and not IsEntityAttached(vehicle) and isTowableVehicle(vehicle) then
			local vehicleCoords = GetEntityCoords(vehicle)
			local distance = #(vehicleCoords - towTruckCoords)
			if distance <= (tonumber(Config.AttachSearchRadius) or 11.0) and distance < bestDistance then
				local offset = GetOffsetFromEntityGivenWorldCoords(towTruck, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z)
				local rearDistance = math.abs(offset.y)
				if offset.y < 0.0
					and rearDistance >= (tonumber(Config.AttachRearMinDistance) or 1.5)
					and rearDistance <= (tonumber(Config.AttachRearMaxDistance) or 9.5)
					and math.abs(offset.x) <= (tonumber(Config.AttachMaxSideOffset) or 3.6)
					and math.abs(offset.z) <= (tonumber(Config.AttachMaxHeightOffset) or 2.8)
					and not isVehicleOccupied(vehicle) then
					bestVehicle = vehicle
					bestDistance = distance
				end
			end
		end
	end

	if bestVehicle then
		return bestVehicle, nil
	end

	return nil, 'Move the disabled vehicle behind your tow truck before trying again.'
end

local function spawnTowTruck(depot)
	if not depot then
		return
	end

	if towTruckSpawnInProgress then
		return
	end

	if assignedTowTruck and DoesEntityExist(assignedTowTruck) then
		notify('Return your current tow truck before spawning another one.')
		return
	end

	local playerPed = PlayerPedId()
	if IsPedInAnyVehicle(playerPed, false) then
		notify('Exit your current vehicle before collecting a tow truck.')
		return
	end

	towTruckSpawnInProgress = true

	local modelHash = loadVehicleModel(Config.VehicleModel)
	if not modelHash then
		towTruckSpawnInProgress = false
		notify('Tow truck model could not be loaded.')
		return
	end

	local spawn = depot.vehicleSpawn
	if not spawn or not spawn.coords then
		towTruckSpawnInProgress = false
		SetModelAsNoLongerNeeded(modelHash)
		notify('Tow yard spawn point is not configured correctly.')
		return
	end

	local vehicle = CreateVehicle(modelHash, spawn.coords.x, spawn.coords.y, spawn.coords.z, spawn.heading or 0.0, true, false)
	if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
		towTruckSpawnInProgress = false
		SetModelAsNoLongerNeeded(modelHash)
		notify('Company tow truck could not be spawned. Make sure the yard bay is clear.')
		return
	end

	assignedTowTruck = vehicle
	SetEntityAsMissionEntity(assignedTowTruck, true, true)
	SetVehicleNumberPlateText(assignedTowTruck, string.sub((Config.VehiclePlatePrefix or 'TOW') .. tostring(GetPlayerServerId(PlayerId())), 1, 8))
	prepareCompanyTowTruck(assignedTowTruck)
	TaskWarpPedIntoVehicle(playerPed, assignedTowTruck, -1)
	SetModelAsNoLongerNeeded(modelHash)
	towTruckSpawnInProgress = false
	notify(('Company tow truck ready. Press %s to attach or detach a nearby vehicle.'):format(tostring(Config.HookKeyDefault or 'G')))
end

local function returnTowTruck()
	if not assignedTowTruck or not DoesEntityExist(assignedTowTruck) then
		notify('No company tow truck is currently assigned to you.')
		return
	end

	local playerPed = PlayerPedId()
	if GetVehiclePedIsIn(playerPed, false) ~= assignedTowTruck then
		notify('Sit in your tow truck before returning it.')
		return
	end

	if getAttachedVehicle(assignedTowTruck) then
		notify('Detach the towed vehicle before returning your tow truck.')
		return
	end

	ensureTowTruckDeleted()
	notify('Tow truck returned to the yard.')
end

local function toggleTowHook()
	if not isTowOnDuty() then
		return
	end

	if not assignedTowTruck or not DoesEntityExist(assignedTowTruck) then
		notify('No company tow truck is assigned to you.')
		return
	end

	local playerPed = PlayerPedId()
	if GetVehiclePedIsIn(playerPed, false) ~= assignedTowTruck or GetPedInVehicleSeat(assignedTowTruck, -1) ~= playerPed then
		notify('You need to be in the driver seat of your tow truck to use the hook controls.')
		return
	end

	local attachedVehicle = getAttachedVehicle(assignedTowTruck)
	if attachedVehicle then
		if not requestEntityControl(attachedVehicle) then
			notify('Tow release failed because the vehicle is not under local control yet.')
			return
		end

		DetachVehicleFromTowTruck(assignedTowTruck, attachedVehicle)
		SetVehicleOnGroundProperly(attachedVehicle)
		notify('Vehicle released from the tow truck.')
		return
	end

	local candidate, errorMessage = findTowCandidate(assignedTowTruck)
	if not candidate then
		notify(errorMessage or 'No towable vehicle is lined up behind the truck.')
		return
	end

	if not requestEntityControl(candidate) then
		notify('Tow hook failed because the target vehicle is not under local control yet.')
		return
	end

	local attachOffset = Config.AttachOffset or {}
	AttachVehicleToTowTruck(
		assignedTowTruck,
		candidate,
		false,
		tonumber(attachOffset.x) or 0.0,
		tonumber(attachOffset.y) or -2.8,
		tonumber(attachOffset.z) or 1.05
	)

	if IsEntityAttachedToEntity(candidate, assignedTowTruck) then
		notify('Vehicle secured to the tow truck.')
		return
	end

	notify('Tow hook could not secure that vehicle. Try lining it up more directly behind the truck.')
end

RegisterNetEvent('lsrp_towing:client:notify', function(message)
	notify(message)
end)

RegisterNetEvent('lsrp_towing:client:dutyResult', function(payload)
	payload = type(payload) == 'table' and payload or {}
	if payload.message then
		notify(payload.message)
	end
end)

RegisterNetEvent('lsrp_towing:client:removeImpoundedVehicle', function(payload)
	payload = type(payload) == 'table' and payload or {}
	if deleteVehicleByNetId(payload.netId) then
		notify(payload.message or 'Unregistered vehicle removed from the roadway.')
		return
	end

	notify('The unregistered vehicle could not be removed immediately.')
end)

RegisterNetEvent('lsrp_jobs:client:employmentUpdated', function()
	if not isTowEmployee() then
		ensureTowTruckDeleted()
	end
end)

RegisterCommand(Config.HookCommand or '+lsrptowhook', function()
	toggleTowHook()
end, false)

RegisterCommand(Config.UnhookCommand or '-lsrptowhook', function()
	return
end, false)

RegisterCommand(Config.ImpoundCommand or 'impound', function()
	impoundFacingVehicle()
end, false)

RegisterKeyMapping(
	Config.HookCommand or '+lsrptowhook',
	'Towing: attach or detach nearby vehicle',
	'keyboard',
	Config.HookKeyDefault or 'G'
)

CreateThread(function()
	createDepotBlips()

	while true do
		local waitMs = 750
		local playerPed = PlayerPedId()

		if playerPed ~= 0 and DoesEntityExist(playerPed) then
			local playerCoords = GetEntityCoords(playerPed)

			for _, depot in ipairs(Config.Depots or {}) do
				local drawDistance = tonumber(Config.DrawDistance) or 30.0
				local interactionDistance = tonumber(Config.InteractionDistance) or 2.5
				local dutyDistance = #(playerCoords - depot.dutyCoords)
				local spawnDistance = #(playerCoords - depot.vehicleSpawn.coords)
				local returnDistance = #(playerCoords - depot.vehicleReturn)

				if dutyDistance <= drawDistance or spawnDistance <= drawDistance or returnDistance <= drawDistance then
					waitMs = 0
				end

				if dutyDistance <= drawDistance then
					DrawMarker(1, depot.dutyCoords.x, depot.dutyCoords.y, depot.dutyCoords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.65, 1.65, 0.7, 242, 159, 88, 110, false, false, 2, false, nil, nil, false)
				end

				if spawnDistance <= drawDistance then
					DrawMarker(36, depot.vehicleSpawn.coords.x, depot.vehicleSpawn.coords.y, depot.vehicleSpawn.coords.z + 0.45, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.55, 0.55, 0.55, 242, 159, 88, 150, false, false, 2, false, nil, nil, false)
				end

				if returnDistance <= drawDistance then
					DrawMarker(1, depot.vehicleReturn.x, depot.vehicleReturn.y, depot.vehicleReturn.z - 1.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.2, 2.2, 0.8, 222, 107, 94, 110, false, false, 2, false, nil, nil, false)
				end

				if isTowEmployee() and dutyDistance <= interactionDistance then
					if isTowOnDuty() then
						showHelpPrompt('Press ~INPUT_CONTEXT~ to clock out of tow duty')
						if isInteractionJustPressed() then
							if assignedTowTruck and DoesEntityExist(assignedTowTruck) then
								notify('Return your company tow truck before clocking out.')
							else
								TriggerServerEvent('lsrp_towing:server:toggleDuty', false)
							end
							Wait(300)
						end
					else
						showHelpPrompt('Press ~INPUT_CONTEXT~ to clock in for tow duty')
						if isInteractionJustPressed() then
							TriggerServerEvent('lsrp_towing:server:toggleDuty', true)
							Wait(300)
						end
					end
				elseif dutyDistance <= interactionDistance then
					showHelpPrompt('Apply for the towing job before using the recovery yard')
					if isInteractionJustPressed() then
						notify('The recovery yard is only available to LS Recovery & Tow employees.')
						Wait(300)
					end
				end

				if isTowOnDuty() and spawnDistance <= interactionDistance then
					showHelpPrompt('Press ~INPUT_CONTEXT~ to collect a company tow truck')
					if isInteractionJustPressed() then
						spawnTowTruck(depot)
						Wait(300)
					end
				elseif isTowEmployee() and spawnDistance <= interactionDistance then
					showHelpPrompt('Clock in for tow duty before collecting a tow truck')
				elseif spawnDistance <= interactionDistance then
					showHelpPrompt('Apply for the towing job before using the company tow bay')
				end

				if returnDistance <= interactionDistance then
					showHelpPrompt('Press ~INPUT_CONTEXT~ to return your company tow truck')
					if isInteractionJustPressed() then
						returnTowTruck()
						Wait(300)
					end
				end
			end

			if isTowOnDuty() and assignedTowTruck and DoesEntityExist(assignedTowTruck) then
				if GetVehiclePedIsIn(playerPed, false) == assignedTowTruck and GetPedInVehicleSeat(assignedTowTruck, -1) == playerPed then
					waitMs = 0
					if getAttachedVehicle(assignedTowTruck) then
						showHelpPrompt(('Press ~INPUT_DETONATE~ or %s to detach the towed vehicle'):format(tostring(Config.HookKeyDefault or 'G')))
					else
						showHelpPrompt(('Press ~INPUT_DETONATE~ or %s to attach a vehicle lined up behind the truck'):format(tostring(Config.HookKeyDefault or 'G')))
					end
				end
			end
		end

		Wait(waitMs)
	end
end)

CreateThread(function()
	while true do
		if assignedTowTruck and not DoesEntityExist(assignedTowTruck) then
			assignedTowTruck = nil
			towTruckSpawnInProgress = false
		end

		Wait(1000)
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		destroyDepotBlips()
		ensureTowTruckDeleted()
	end
end)