local activeAssignment = nil
local activeAssignmentBlip = nil
local depotBlips = {}
local spawnedTaxiVehicle = nil
local pendingAutoSpawnDepotId = nil
local taxiVehicleSpawnInProgress = false

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

local function isTaxiEmployee()
	local playerState = LocalPlayer and LocalPlayer.state
	return playerState and playerState.lsrp_job == Config.JobId or false
end

local function isTaxiOnDuty()
	local playerState = LocalPlayer and LocalPlayer.state
	return playerState and playerState.lsrp_job == Config.JobId and playerState.lsrp_job_duty == true or false
end

local function clearAssignmentBlip()
	if activeAssignmentBlip then
		RemoveBlip(activeAssignmentBlip)
		activeAssignmentBlip = nil
	end
end

local function setAssignmentBlip(coords, label)
	clearAssignmentBlip()
	if not coords then
		return
	end

	activeAssignmentBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
	SetBlipSprite(activeAssignmentBlip, 280)
	SetBlipRoute(activeAssignmentBlip, true)
	SetBlipColour(activeAssignmentBlip, 46)
	SetBlipScale(activeAssignmentBlip, 0.9)
	BeginTextCommandSetBlipName('STRING')
	AddTextComponentSubstringPlayerName(trimString(label) or 'Taxi Assignment')
	EndTextCommandSetBlipName(activeAssignmentBlip)
	SetNewWaypoint(coords.x, coords.y)
end

local function refreshAssignmentBlip()
	if type(activeAssignment) ~= 'table' then
		clearAssignmentBlip()
		return
	end

	if activeAssignment.stage == 'dropoff' and activeAssignment.destination and activeAssignment.destination.coords then
		setAssignmentBlip(activeAssignment.destination.coords, ('Drop-off: %s'):format(tostring(activeAssignment.destination.label or 'Destination')))
		return
	end

	if activeAssignment.pickup and activeAssignment.pickup.coords then
		setAssignmentBlip(activeAssignment.pickup.coords, ('Pickup: %s'):format(tostring(activeAssignment.pickup.label or 'Passenger')))
		return
	end

	clearAssignmentBlip()
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
	taxiVehicleSpawnInProgress = false
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
	if not depot then
		return
	end

	if taxiVehicleSpawnInProgress then
		return
	end

	if spawnedTaxiVehicle and DoesEntityExist(spawnedTaxiVehicle) then
		notify('Return your current taxi before spawning another one.')
		return
	end

	local playerPed = PlayerPedId()
	if IsPedInAnyVehicle(playerPed, false) then
		notify('Exit your current vehicle before collecting a taxi.')
		return
	end

	taxiVehicleSpawnInProgress = true

	local modelHash = loadVehicleModel(Config.VehicleModel)
	if not modelHash then
		taxiVehicleSpawnInProgress = false
		notify('Taxi vehicle model could not be loaded.')
		return
	end

	local spawn = depot.vehicleSpawn
	if not spawn or not spawn.coords then
		taxiVehicleSpawnInProgress = false
		notify('Taxi depot spawn point is not configured correctly.')
		SetModelAsNoLongerNeeded(modelHash)
		return
	end

	local vehicle = CreateVehicle(modelHash, spawn.coords.x, spawn.coords.y, spawn.coords.z, spawn.heading or 0.0, true, false)
	if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
		taxiVehicleSpawnInProgress = false
		SetModelAsNoLongerNeeded(modelHash)
		notify('Company taxi could not be spawned at the depot. Make sure the spawn bay is clear.')
		return
	end

	spawnedTaxiVehicle = vehicle
	SetVehicleOnGroundProperly(spawnedTaxiVehicle)
	SetVehicleDirtLevel(spawnedTaxiVehicle, 0.0)
	SetVehicleColours(spawnedTaxiVehicle, 88, 88)
	SetVehicleExtraColours(spawnedTaxiVehicle, 0, 0)
	SetVehicleNumberPlateText(spawnedTaxiVehicle, string.sub((Config.VehiclePlatePrefix or 'CAB') .. tostring(GetPlayerServerId(PlayerId())), 1, 8))
	SetEntityAsMissionEntity(spawnedTaxiVehicle, true, true)
	prepareCompanyTaxiVehicle(spawnedTaxiVehicle)
	TaskWarpPedIntoVehicle(playerPed, spawnedTaxiVehicle, -1)
	SetModelAsNoLongerNeeded(modelHash)
	taxiVehicleSpawnInProgress = false
	notify('Company taxi ready. Claim a ride from the Taxi phone app dispatch board.')
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

	if taxiVehicleSpawnInProgress then
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

	ensureTaxiVehicleDeleted()
	notify('Taxi returned to the depot.')
end

local function clearAssignment(message)
	activeAssignment = nil
	clearAssignmentBlip()
	if message then
		notify(message)
	end
end

local function getAssignmentTarget()
	if type(activeAssignment) ~= 'table' then
		return nil, nil, nil
	end

	if activeAssignment.stage == 'dropoff' and activeAssignment.destination and activeAssignment.destination.coords then
		return activeAssignment.destination, tonumber(Config.DestinationRadius) or 24.0, 'dropoff'
	end

	if activeAssignment.pickup and activeAssignment.pickup.coords then
		return activeAssignment.pickup, tonumber(Config.PickupRadius) or 18.0, 'pickup'
	end

	return nil, nil, nil
end

RegisterNetEvent('lsrp_taxi:client:notify', function(message)
	notify(message)
end)

RegisterNetEvent('lsrp_jobs:client:employmentUpdated', function()
	if not isTaxiEmployee() then
		clearAssignment()
		ensureTaxiVehicleDeleted()
		pendingAutoSpawnDepotId = nil
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
		clearAssignment()
	end
end)

RegisterNetEvent('lsrp_taxi:client:assignmentUpdated', function(payload)
	payload = type(payload) == 'table' and payload or {}
	activeAssignment = payload
	refreshAssignmentBlip()

	if payload.stage == 'dropoff' then
		notify(('Passenger onboard. Drive to %s.'):format(tostring(payload.destination and payload.destination.label or 'the destination')))
	else
		notify(('Dispatch assigned ride #%s. Head to %s.'):format(tostring(payload.id or '?'), tostring(payload.pickup and payload.pickup.label or 'the pickup point')))
	end
end)

RegisterNetEvent('lsrp_taxi:client:assignmentCleared', function(payload)
	payload = type(payload) == 'table' and payload or {}
	clearAssignment(payload.message)
end)

RegisterNetEvent('lsrp_taxi:client:fareCompleted', function(payload)
	payload = type(payload) == 'table' and payload or {}
	activeAssignment = nil
	clearAssignmentBlip()
	if payload.payoutFailed == true then
		if payload.riderChargeError == 'insufficient_funds' then
			notify(('Ride complete for %s, but the passenger could not pay %s.'):format(tostring(payload.label or 'destination'), tostring(payload.formattedPayout or 'LS$0')))
		elseif payload.refundIssued == true then
			notify(('Ride complete for %s, but the %s charge was refunded because payout failed.'):format(tostring(payload.label or 'destination'), tostring(payload.formattedPayout or 'LS$0')))
		else
			notify(('Ride complete for %s, but the %s payment could not be settled.'):format(tostring(payload.label or 'destination'), tostring(payload.formattedPayout or 'LS$0')))
		end
		return
	end

	if payload.riderCharged == true then
		notify(('Ride complete: %s paid by the passenger for %s.'):format(tostring(payload.formattedPayout or 'LS$0'), tostring(payload.label or 'destination')))
		return
	end

	notify(('Ride complete for %s. No fare was charged.'):format(tostring(payload.label or 'destination')))
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
					showHelpPrompt('Apply for the live taxi job before using the company vehicle bay')
					if isInteractionJustPressed() then
						notify('The company taxi bay is only available to Downtown Cab Live employees.')
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

			local assignmentTarget, assignmentRadius, assignmentStage = getAssignmentTarget()
			if assignmentTarget and assignmentTarget.coords then
				local targetCoords = vector3(assignmentTarget.coords.x, assignmentTarget.coords.y, assignmentTarget.coords.z)
				local assignmentDistance = #(playerCoords - targetCoords)
				if assignmentDistance <= (tonumber(Config.DrawDistance) or 30.0) then
					waitMs = 0
					if assignmentStage == 'pickup' then
						DrawMarker(1, assignmentTarget.coords.x, assignmentTarget.coords.y, assignmentTarget.coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2.0, 0.75, 87, 176, 255, 120, false, false, 2, false, nil, nil, false)
					else
						DrawMarker(1, assignmentTarget.coords.x, assignmentTarget.coords.y, assignmentTarget.coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.2, 2.2, 0.8, 99, 200, 138, 120, false, false, 2, false, nil, nil, false)
					end

					if assignmentDistance <= assignmentRadius then
						local currentVehicle = GetVehiclePedIsIn(playerPed, false)
						if currentVehicle ~= 0 and currentVehicle == spawnedTaxiVehicle then
							if assignmentStage == 'pickup' then
								showHelpPrompt('Press ~INPUT_CONTEXT~ to confirm the passenger is onboard')
								if isInteractionJustPressed() then
									TriggerServerEvent('lsrp_taxi:server:markPassengerPickedUp')
									Wait(300)
								end
							else
								showHelpPrompt('Press ~INPUT_CONTEXT~ to complete the taxi ride')
								if isInteractionJustPressed() then
									TriggerServerEvent('lsrp_taxi:server:completeRide')
									Wait(300)
								end
							end
						elseif assignmentStage == 'pickup' then
							showHelpPrompt('Pull up in your company taxi to collect the passenger')
						else
							showHelpPrompt('Use your company taxi to complete the ride')
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
			taxiVehicleSpawnInProgress = false
		end

		if pendingAutoSpawnDepotId then
			tryAutoSpawnAssignedTaxi()
		end

		Wait(1000)
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		clearAssignmentBlip()
		destroyDepotBlips()
		ensureTaxiVehicleDeleted()
	end
end)
