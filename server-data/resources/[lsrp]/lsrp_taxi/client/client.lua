local activeFare = nil
local activeFareBlip = nil
local farePassengerPed = nil
local fareInteractionInProgress = false
local taxiAvailabilityReported = false
local depotBlips = {}
local spawnedTaxiVehicle = nil
local pendingAutoSpawnDepotId = nil

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
	EndTextCommandDisplayHelp(0, false, true, -1)
end

local function isInteractionJustPressed()
	local control = math.floor(tonumber(Config.InteractionKey) or 38)
	return IsControlJustPressed(0, control) or IsDisabledControlJustPressed(0, control)
end

local function isTaxiEmployee()
	local playerState = LocalPlayer and LocalPlayer.state
	return playerState and playerState.lsrp_job == Config.JobId or false
end

local function isTaxiOnDuty()
	local playerState = LocalPlayer and LocalPlayer.state
	return playerState and playerState.lsrp_job == Config.JobId and playerState.lsrp_job_duty == true or false
end

local function setTaxiAvailabilityReported(isAvailable)
	local desiredState = isAvailable == true
	if taxiAvailabilityReported == desiredState then
		return
	end

	taxiAvailabilityReported = desiredState
	TriggerServerEvent('lsrp_taxi:server:setTaxiAvailability', desiredState)
end

local function clearFareBlip()
	if activeFareBlip then
		RemoveBlip(activeFareBlip)
		activeFareBlip = nil
	end
end

local function clearFarePassenger()
	if farePassengerPed and DoesEntityExist(farePassengerPed) then
		SetEntityAsMissionEntity(farePassengerPed, true, true)
		DeletePed(farePassengerPed)
	end

	farePassengerPed = nil
	fareInteractionInProgress = false
end

local function clearFarePassengerLater(delayMs)
	if not farePassengerPed or not DoesEntityExist(farePassengerPed) then
		return
	end

	local passengerPed = farePassengerPed
	CreateThread(function()
		Wait(math.max(0, math.floor(tonumber(delayMs) or 0)))
		if farePassengerPed == passengerPed then
			clearFarePassenger()
		end
	end)
end

local function assignFarePassengerWaitingTask(passengerPed)
	if not passengerPed or passengerPed == 0 or not DoesEntityExist(passengerPed) then
		return
	end

	SetBlockingOfNonTemporaryEvents(passengerPed, true)
	SetEntityInvincible(passengerPed, true)
	SetPedCanRagdoll(passengerPed, false)
	ClearPedTasks(passengerPed)
	ClearPedSecondaryTask(passengerPed)
	TaskStartScenarioInPlace(passengerPed, tostring(Config.PassengerWaitScenario or 'WORLD_HUMAN_STAND_IMPATIENT'), 0, true)
end

local function getPassengerBoardingTarget(vehicle, seatIndex)
	if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
		return nil
	end

	if seatIndex == 2 then
		return GetOffsetFromEntityInWorldCoords(vehicle, 1.2, -2.2, 0.0)
	end

	if seatIndex == 1 then
		return GetOffsetFromEntityInWorldCoords(vehicle, -1.2, -2.2, 0.0)
	end

	return GetOffsetFromEntityInWorldCoords(vehicle, 1.1, 0.8, 0.0)
end

local function startPassengerBoardingAttempt(passengerPed, vehicle, seatIndex)
	if not passengerPed or passengerPed == 0 or not DoesEntityExist(passengerPed) or not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
		return
	end

	local boardingTarget = getPassengerBoardingTarget(vehicle, seatIndex)
	SetBlockingOfNonTemporaryEvents(passengerPed, false)
	SetEntityInvincible(passengerPed, true)
	SetPedCanRagdoll(passengerPed, false)
	FreezeEntityPosition(passengerPed, false)
	ClearPedTasksImmediately(passengerPed)
	ClearPedSecondaryTask(passengerPed)

	if boardingTarget then
		TaskGoStraightToCoord(passengerPed, boardingTarget.x, boardingTarget.y, boardingTarget.z, 1.0, 3000, 0.0, 0.0)
	end

	CreateThread(function()
		Wait(600)
		if farePassengerPed ~= passengerPed or not DoesEntityExist(passengerPed) or not DoesEntityExist(vehicle) or IsPedInVehicle(passengerPed, vehicle, false) then
			return
		end

		TaskEnterVehicle(passengerPed, vehicle, 8000, seatIndex, 1.0, 1, 0)
	end)
end

local function getPassengerWalkAwayTarget(vehicle, passengerPed)
	if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or not passengerPed or passengerPed == 0 or not DoesEntityExist(passengerPed) then
		return nil
	end

	local passengerCoords = GetEntityCoords(passengerPed)
	local rightTarget = GetOffsetFromEntityInWorldCoords(vehicle, 5.5, -8.0, 0.0)
	local leftTarget = GetOffsetFromEntityInWorldCoords(vehicle, -5.5, -8.0, 0.0)
	local rightDistance = #(passengerCoords - rightTarget)
	local leftDistance = #(passengerCoords - leftTarget)

	if rightDistance < leftDistance then
		return rightTarget
	end

	return leftTarget
end

local function makeFarePassengerWalkAway(vehicle, passengerPed)
	if not passengerPed or passengerPed == 0 or not DoesEntityExist(passengerPed) then
		return
	end

	local walkTarget = getPassengerWalkAwayTarget(vehicle, passengerPed)
	ClearPedTasks(passengerPed)
	SetBlockingOfNonTemporaryEvents(passengerPed, false)
	SetEntityInvincible(passengerPed, false)
	SetPedCanRagdoll(passengerPed, true)

	if walkTarget then
		TaskGoStraightToCoord(passengerPed, walkTarget.x, walkTarget.y, walkTarget.z, 1.0, 8000, 0.0, 0.0)
		CreateThread(function()
			Wait(8000)
			if farePassengerPed == passengerPed and DoesEntityExist(passengerPed) then
				TaskWanderStandard(passengerPed, 10.0, 10)
			end
		end)
	else
		TaskWanderStandard(passengerPed, 10.0, 10)
	end
end

local function setFareBlip(coords, label)
	clearFareBlip()
	if not coords then
		return
	end

	activeFareBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
	SetBlipSprite(activeFareBlip, 280)
	SetBlipRoute(activeFareBlip, true)
	SetBlipColour(activeFareBlip, 46)
	SetBlipScale(activeFareBlip, 0.9)
	BeginTextCommandSetBlipName('STRING')
	AddTextComponentSubstringPlayerName(trimString(label) or 'Taxi Fare')
	EndTextCommandSetBlipName(activeFareBlip)
	SetNewWaypoint(coords.x, coords.y)
end

local function getFareTarget()
	if type(activeFare) ~= 'table' then
		return nil
	end

	if activeFare.stage == 'pickup' then
		return activeFare.pickup, tonumber(Config.PickupRadius) or 18.0
	end

	if activeFare.stage == 'dropoff' then
		return activeFare.destination, tonumber(Config.DestinationRadius) or 24.0
	end

	return nil
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
			SetBlipSprite(blip, math.floor(tonumber(blipConfig.sprite) or 198))
			SetBlipDisplay(blip, 4)
			SetBlipScale(blip, tonumber(blipConfig.scale) or 0.82)
			SetBlipColour(blip, math.floor(tonumber(blipConfig.color) or 46))
			SetBlipAsShortRange(blip, true)
			BeginTextCommandSetBlipName('STRING')
			AddTextComponentSubstringPlayerName(trimString(blipConfig.label) or trimString(depot.label) or 'Taxi Depot')
			EndTextCommandSetBlipName(blip)
			depotBlips[#depotBlips + 1] = blip
		end
	end
end

local function ensureTaxiVehicleDeleted()
	if spawnedTaxiVehicle and DoesEntityExist(spawnedTaxiVehicle) then
		SetEntityAsMissionEntity(spawnedTaxiVehicle, true, true)
		DeleteVehicle(spawnedTaxiVehicle)
	end

	spawnedTaxiVehicle = nil
	setTaxiAvailabilityReported(false)
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

local function loadPedModel(modelName)
	local modelHash = GetHashKey(modelName)
	if not IsModelInCdimage(modelHash) or not IsModelAPed(modelHash) then
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

local function getPassengerSeat(vehicle)
	for _, seatIndex in ipairs({ 2, 1, 0 }) do
		if IsVehicleSeatFree(vehicle, seatIndex) then
			return seatIndex
		end
	end

	return nil
end

local function ensureFarePassengerSpawned()
	if farePassengerPed and DoesEntityExist(farePassengerPed) then
		return farePassengerPed
	end

	if type(activeFare) ~= 'table' or activeFare.stage ~= 'pickup' or type(activeFare.pickup) ~= 'table' or not activeFare.pickup.coords then
		return nil
	end

	local modelHash = loadPedModel(activeFare.passengerModel or 'a_m_m_business_01')
	if not modelHash then
		notify('Taxi passenger model could not be loaded.')
		return nil
	end

	local pickupCoords = activeFare.pickup.coords
	local heading = tonumber(activeFare.pickup.heading) or 0.0
	farePassengerPed = CreatePed(4, modelHash, pickupCoords.x, pickupCoords.y, pickupCoords.z - 1.0, heading, false, false)
	SetModelAsNoLongerNeeded(modelHash)

	if not farePassengerPed or farePassengerPed == 0 or not DoesEntityExist(farePassengerPed) then
		farePassengerPed = nil
		notify('Taxi passenger could not be created at the pickup point.')
		return nil
	end

	SetEntityAsMissionEntity(farePassengerPed, true, true)
	SetEntityHeading(farePassengerPed, heading)
	SetEntityCoordsNoOffset(farePassengerPed, pickupCoords.x, pickupCoords.y, pickupCoords.z, false, false, false)
	SetBlockingOfNonTemporaryEvents(farePassengerPed, true)
	SetPedFleeAttributes(farePassengerPed, 0, false)
	SetPedCanRagdoll(farePassengerPed, false)
	SetPedKeepTask(farePassengerPed, true)
	SetEntityInvincible(farePassengerPed, true)
	assignFarePassengerWaitingTask(farePassengerPed)

	return farePassengerPed
end

local function boardFarePassenger()
	if fareInteractionInProgress or type(activeFare) ~= 'table' or activeFare.stage ~= 'pickup' then
		return
	end

	local playerPed = PlayerPedId()
	local currentVehicle = GetVehiclePedIsIn(playerPed, false)
	if currentVehicle == 0 or currentVehicle ~= spawnedTaxiVehicle then
		notify('Pull up in your company taxi to collect the passenger.')
		return
	end

	local seatIndex = getPassengerSeat(spawnedTaxiVehicle)
	if seatIndex == nil then
		notify('There is no free passenger seat in your taxi.')
		return
	end

	local passengerPed = ensureFarePassengerSpawned()
	if not passengerPed then
		return
	end

	fareInteractionInProgress = true
	startPassengerBoardingAttempt(passengerPed, spawnedTaxiVehicle, seatIndex)

	CreateThread(function()
		local timeoutAt = GetGameTimer() + 12000
		local lastRetryAt = GetGameTimer()
		while farePassengerPed == passengerPed and DoesEntityExist(passengerPed) and GetGameTimer() < timeoutAt do
			if IsPedInVehicle(passengerPed, spawnedTaxiVehicle, false) then
				fareInteractionInProgress = false
				TriggerServerEvent('lsrp_taxi:server:pickupPassenger', activeFare.pickupId)
				return
			end

			if GetGameTimer() - lastRetryAt >= 2500 then
				lastRetryAt = GetGameTimer()
				startPassengerBoardingAttempt(passengerPed, spawnedTaxiVehicle, seatIndex)
			end

			Wait(250)
		end

		fareInteractionInProgress = false
		if farePassengerPed == passengerPed and DoesEntityExist(passengerPed) and not IsPedInVehicle(passengerPed, spawnedTaxiVehicle, false) then
			notify('The passenger did not get into your taxi. Reposition the vehicle and try again.')
			assignFarePassengerWaitingTask(passengerPed)
		end
	end)
end

local function dropOffFarePassenger()
	if fareInteractionInProgress or type(activeFare) ~= 'table' or activeFare.stage ~= 'dropoff' then
		return
	end

	local playerPed = PlayerPedId()
	local currentVehicle = GetVehiclePedIsIn(playerPed, false)
	if currentVehicle == 0 or currentVehicle ~= spawnedTaxiVehicle then
		notify('Use your company taxi to drop off the passenger.')
		return
	end

	if not farePassengerPed or not DoesEntityExist(farePassengerPed) or not IsPedInVehicle(farePassengerPed, spawnedTaxiVehicle, false) then
		notify('The passenger is not in your taxi anymore.')
		TriggerServerEvent('lsrp_taxi:server:completeFare', activeFare.destinationId)
		return
	end

	fareInteractionInProgress = true
	TaskLeaveVehicle(farePassengerPed, spawnedTaxiVehicle, 0)

	CreateThread(function()
		local passengerPed = farePassengerPed
		local timeoutAt = GetGameTimer() + 10000
		while passengerPed and DoesEntityExist(passengerPed) and GetGameTimer() < timeoutAt do
			if not IsPedInVehicle(passengerPed, spawnedTaxiVehicle, false) then
				makeFarePassengerWalkAway(spawnedTaxiVehicle, passengerPed)
				fareInteractionInProgress = false
				TriggerServerEvent('lsrp_taxi:server:completeFare', activeFare.destinationId)
				return
			end

			Wait(250)
		end

		fareInteractionInProgress = false
		TriggerServerEvent('lsrp_taxi:server:completeFare', activeFare.destinationId)
		if passengerPed and DoesEntityExist(passengerPed) then
			ClearPedTasks(passengerPed)
		end
	end)
end

local function prepareCompanyTaxiVehicle(vehicle)
	if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
		return
	end

	SetVehicleDoorsLocked(vehicle, 1)
	SetVehicleDoorsLockedForAllPlayers(vehicle, false)
	SetVehicleNeedsToBeHotwired(vehicle, false)
	SetVehicleEngineOn(vehicle, false, true, true)

	local entityState = Entity(vehicle).state
	local localStateId = tonumber(LocalPlayer and LocalPlayer.state and LocalPlayer.state.state_id)
	if entityState then
		entityState:set('lsrpVehicleLocked', false, true)
		if localStateId and localStateId > 0 then
			entityState:set('lsrpVehicleOwnerStateId', localStateId, true)
		end
	end
end

local function spawnTaxiVehicle(depot)
	if not depot or spawnedTaxiVehicle and DoesEntityExist(spawnedTaxiVehicle) then
		notify('Return your current taxi before spawning another one.')
		return
	end

	local playerPed = PlayerPedId()
	if IsPedInAnyVehicle(playerPed, false) then
		notify('Exit your current vehicle before collecting a taxi.')
		return
	end

	local modelHash = loadVehicleModel(Config.VehicleModel)
	if not modelHash then
		notify('Taxi vehicle model could not be loaded.')
		return
	end

	local spawn = depot.vehicleSpawn
	if not spawn or not spawn.coords then
		notify('Taxi depot spawn point is not configured correctly.')
		SetModelAsNoLongerNeeded(modelHash)
		return
	end

	spawnedTaxiVehicle = CreateVehicle(modelHash, spawn.coords.x, spawn.coords.y, spawn.coords.z, spawn.heading or 0.0, true, false)
	if not spawnedTaxiVehicle or spawnedTaxiVehicle == 0 or not DoesEntityExist(spawnedTaxiVehicle) then
		spawnedTaxiVehicle = nil
		SetModelAsNoLongerNeeded(modelHash)
		notify('Company taxi could not be spawned at the depot. Make sure the spawn bay is clear.')
		return
	end

	SetVehicleOnGroundProperly(spawnedTaxiVehicle)
	SetVehicleDirtLevel(spawnedTaxiVehicle, 0.0)
	SetVehicleColours(spawnedTaxiVehicle, 88, 88)
	SetVehicleExtraColours(spawnedTaxiVehicle, 0, 0)
	SetVehicleNumberPlateText(spawnedTaxiVehicle, string.sub((Config.VehiclePlatePrefix or 'TAXI') .. tostring(GetPlayerServerId(PlayerId())), 1, 8))
	SetEntityAsMissionEntity(spawnedTaxiVehicle, true, true)
	prepareCompanyTaxiVehicle(spawnedTaxiVehicle)
	TaskWarpPedIntoVehicle(playerPed, spawnedTaxiVehicle, -1)
	SetModelAsNoLongerNeeded(modelHash)
	setTaxiAvailabilityReported(true)
	notify('Taxi vehicle ready. Stay available for the next dispatch assignment.')
end

local function findDepotById(depotId)
	local targetId = trimString(depotId)
	if not targetId then
		return nil
	end

	for _, depot in ipairs(Config.Depots or {}) do
		if trimString(depot.id) == targetId then
			return depot
		end
	end

	return nil
end

local function tryAutoSpawnAssignedTaxi()
	if not pendingAutoSpawnDepotId or not isTaxiOnDuty() then
		return
	end

	if spawnedTaxiVehicle and DoesEntityExist(spawnedTaxiVehicle) then
		pendingAutoSpawnDepotId = nil
		return
	end

	local depot = findDepotById(pendingAutoSpawnDepotId)
	if not depot then
		pendingAutoSpawnDepotId = nil
		return
	end

	spawnTaxiVehicle(depot)
	if spawnedTaxiVehicle and DoesEntityExist(spawnedTaxiVehicle) then
		pendingAutoSpawnDepotId = nil
	end
end

local function returnTaxiVehicle()
	if not spawnedTaxiVehicle or not DoesEntityExist(spawnedTaxiVehicle) then
		notify('No company taxi is currently assigned to you.')
		return
	end

	local playerPed = PlayerPedId()
	if GetVehiclePedIsIn(playerPed, false) ~= spawnedTaxiVehicle then
		notify('Sit in your taxi before returning it.')
		return
	end

	clearFareBlip()
	clearFarePassenger()
	activeFare = nil
	ensureTaxiVehicleDeleted()
	notify('Taxi returned to the depot.')
end

RegisterNetEvent('lsrp_jobs:client:employmentUpdated', function()
	if not isTaxiEmployee() then
		activeFare = nil
		clearFareBlip()
		clearFarePassenger()
		ensureTaxiVehicleDeleted()
		pendingAutoSpawnDepotId = nil
		setTaxiAvailabilityReported(false)
	end

	tryAutoSpawnAssignedTaxi()
end)

RegisterNetEvent('lsrp_taxi:client:dutyResult', function(payload)
	payload = type(payload) == 'table' and payload or {}

	if payload.message then
		notify(payload.message)
	end

	if payload.ok == true and payload.onDuty == true then
		tryAutoSpawnAssignedTaxi()
	elseif payload.ok == true and payload.onDuty ~= true then
		pendingAutoSpawnDepotId = nil
		setTaxiAvailabilityReported(false)
	end
end)

RegisterNetEvent('lsrp_taxi:client:fareAssigned', function(payload)
	payload = type(payload) == 'table' and payload or {}
	clearFarePassenger()
	activeFare = payload
	if payload.pickup and payload.pickup.coords then
		setFareBlip(payload.pickup.coords, ('Pickup: %s'):format(tostring(payload.pickup.label or 'Passenger')))
	end
	ensureFarePassengerSpawned()
	notify(('Taxi fare assigned: collect a passenger at %s.'):format(tostring(payload.pickup and payload.pickup.label or 'the pickup point')))
end)

RegisterNetEvent('lsrp_taxi:client:passengerPickedUp', function(payload)
	payload = type(payload) == 'table' and payload or {}
	fareInteractionInProgress = false
	if type(activeFare) ~= 'table' then
		activeFare = {}
	end

	activeFare.stage = 'dropoff'
	activeFare.pickupId = payload.pickupId or activeFare.pickupId
	activeFare.pickup = payload.pickup or activeFare.pickup
	activeFare.destinationId = payload.destinationId or activeFare.destinationId
	activeFare.destination = payload.destination or activeFare.destination
	activeFare.payout = payload.payout or activeFare.payout
	activeFare.passengerModel = payload.passengerModel or activeFare.passengerModel

	if activeFare.destination and activeFare.destination.coords then
		setFareBlip(activeFare.destination.coords, ('Drop-off: %s'):format(tostring(activeFare.destination.label or 'Destination')))
	end

	notify(('Passenger onboard. Drive to %s.'):format(tostring(activeFare.destination and activeFare.destination.label or 'the destination')))
end)

RegisterNetEvent('lsrp_taxi:client:fareCleared', function(payload)
	payload = type(payload) == 'table' and payload or {}
	activeFare = nil
	clearFareBlip()
	clearFarePassenger()
	if payload.message then
		notify(payload.message)
	end
end)

RegisterNetEvent('lsrp_taxi:client:fareCompleted', function(payload)
	payload = type(payload) == 'table' and payload or {}
	activeFare = nil
	clearFareBlip()
	clearFarePassengerLater(tonumber(Config.PassengerCleanupDelayMs) or 12000)
	if payload.payoutFailed == true then
		notify(('Fare completed for %s, but the payout failed. Dispatch will send another ride soon.'):format(tostring(payload.label or 'destination')))
		return
	end

	local nextFareDelaySeconds = math.max(0, math.floor(tonumber(payload.nextFareDelaySeconds) or 0))
	if nextFareDelaySeconds > 0 then
		notify(('Fare completed: %s earned for %s. Next ride in about %d minute(s).'):format(tostring(payload.formattedPayout or 'LS$0'), tostring(payload.label or 'destination'), math.max(1, math.floor((nextFareDelaySeconds + 59) / 60))))
		return
	end

	notify(('Fare completed: %s earned for %s.'):format(tostring(payload.formattedPayout or 'LS$0'), tostring(payload.label or 'destination')))
end)

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

				local spawnDistance = #(playerCoords - depot.vehicleSpawn.coords)
				local returnDistance = #(playerCoords - depot.vehicleReturn)

				if spawnDistance <= drawDistance or returnDistance <= drawDistance then
					waitMs = 0
				end

				if spawnDistance <= drawDistance then
					DrawMarker(36, depot.vehicleSpawn.coords.x, depot.vehicleSpawn.coords.y, depot.vehicleSpawn.coords.z + 0.45, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.55, 0.55, 0.55, 99, 200, 138, 150, false, false, 2, false, nil, nil, false)
				end

				if returnDistance <= drawDistance then
					DrawMarker(1, depot.vehicleReturn.x, depot.vehicleReturn.y, depot.vehicleReturn.z - 1.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.2, 2.2, 0.8, 222, 107, 94, 110, false, false, 2, false, nil, nil, false)
				end

				if isTaxiOnDuty() and spawnDistance <= interactionDistance then
					showHelpPrompt('Press ~INPUT_CONTEXT~ to collect a company taxi')
					if isInteractionJustPressed() then
						spawnTaxiVehicle(depot)
						Wait(300)
					end
				elseif isTaxiEmployee() and spawnDistance <= interactionDistance then
					showHelpPrompt('Press ~INPUT_CONTEXT~ to clock in and collect a company taxi')
					if isInteractionJustPressed() then
						pendingAutoSpawnDepotId = depot.id
						TriggerServerEvent('lsrp_taxi:server:toggleDuty', true)
						Wait(300)
					end
				elseif spawnDistance <= interactionDistance then
					showHelpPrompt('Apply for the taxi job before using the company vehicle bay')
					if isInteractionJustPressed() then
						notify('The company taxi bay is only available to Downtown Cab employees.')
						Wait(300)
					end
				elseif isTaxiOnDuty() and returnDistance <= interactionDistance then
					showHelpPrompt('Press ~INPUT_CONTEXT~ to return your company taxi')
					if isInteractionJustPressed() then
						returnTaxiVehicle()
						Wait(300)
					end
				end
			end

			local fareTarget, fareRadius = getFareTarget()
			if fareTarget and fareTarget.coords then
				local fareDistance = #(playerCoords - vector3(fareTarget.coords.x, fareTarget.coords.y, fareTarget.coords.z))
				if fareDistance <= (tonumber(Config.DrawDistance) or 30.0) then
					waitMs = 0
					if activeFare.stage == 'pickup' then
						DrawMarker(1, fareTarget.coords.x, fareTarget.coords.y, fareTarget.coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2.0, 0.75, 87, 176, 255, 120, false, false, 2, false, nil, nil, false)
					else
						DrawMarker(1, fareTarget.coords.x, fareTarget.coords.y, fareTarget.coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.2, 2.2, 0.8, 99, 200, 138, 120, false, false, 2, false, nil, nil, false)
					end

					if fareDistance <= fareRadius then
						local currentVehicle = GetVehiclePedIsIn(playerPed, false)
						if activeFare.stage == 'pickup' then
							if currentVehicle ~= 0 and currentVehicle == spawnedTaxiVehicle then
								showHelpPrompt('Press ~INPUT_CONTEXT~ to collect the passenger')
							elseif currentVehicle == 0 then
								showHelpPrompt('Pull up in your company taxi to collect the passenger')
							else
								showHelpPrompt('Collect the passenger using your company taxi')
							end

							if currentVehicle ~= 0 and currentVehicle == spawnedTaxiVehicle and isInteractionJustPressed() then
								boardFarePassenger()
								Wait(300)
							end
						else
							if currentVehicle ~= 0 and currentVehicle == spawnedTaxiVehicle then
								showHelpPrompt('Press ~INPUT_CONTEXT~ to drop off the passenger')
							elseif currentVehicle == 0 then
								showHelpPrompt('Get back in your company taxi to complete the fare')
							else
								showHelpPrompt('Complete the fare using your company taxi')
							end

							if currentVehicle ~= 0 and currentVehicle == spawnedTaxiVehicle and isInteractionJustPressed() then
								dropOffFarePassenger()
								Wait(300)
							end
						end
					end
				end
			end
		end

		Wait(waitMs)
	end
end)

CreateThread(function()
	while true do
		if spawnedTaxiVehicle and not DoesEntityExist(spawnedTaxiVehicle) then
			spawnedTaxiVehicle = nil
			setTaxiAvailabilityReported(false)
		end

		if pendingAutoSpawnDepotId then
			tryAutoSpawnAssignedTaxi()
			Wait(1000)
		else
			Wait(1000)
		end
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		setTaxiAvailabilityReported(false)
		clearFareBlip()
		clearFarePassenger()
		destroyDepotBlips()
		ensureTaxiVehicleDeleted()
	end
end)