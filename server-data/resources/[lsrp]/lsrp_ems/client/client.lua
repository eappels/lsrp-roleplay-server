local RESOURCE_NAME = GetCurrentResourceName()

local Framework = {}
local activeAction = nil
local activeActionUntil = 0
local activeTransport = nil
local activeEscort = nil
local patientStatusByServerId = {}
local activeTreatment = nil

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

local function debugPrint(message)
	if Config.Debug ~= true then
		return
	end

	print(('[%s] %s'):format(RESOURCE_NAME, tostring(message)))
end

function Framework.notify(message, level)
	if GetResourceState('lsrp_framework') == 'started' then
		exports['lsrp_framework']:notify(trimString(message) or '', level)
		return
	end

	BeginTextCommandThefeedPost('STRING')
	AddTextComponentSubstringPlayerName(tostring(message or ''))
	EndTextCommandThefeedPostTicker(false, true)
end

local function updateTreatmentHud(payload)
	if GetResourceState('lsrp_hud') ~= 'started' then
		return
	end

	TriggerEvent('lsrp_hud:client:setTreatmentCountdown', payload)
end

local function ensureAnimDictLoaded(animDict, timeoutMs)
	if not animDict or animDict == '' then
		return false
	end

	if HasAnimDictLoaded(animDict) then
		return true
	end

	RequestAnimDict(animDict)
	local timeoutAt = GetGameTimer() + math.max(1000, math.floor(tonumber(timeoutMs) or 3000))
	while not HasAnimDictLoaded(animDict) do
		if GetGameTimer() >= timeoutAt then
			return false
		end
		Wait(0)
	end

	return true
end

local function getTreatmentBedObjectHashes(treatment)
	if type(treatment) ~= 'table' then
		return {}
	end

	if treatment.objectHashes ~= nil then
		return treatment.objectHashes
	end

	local hashes = {}
	local models = treatment.objectModels or (Config.Treatment and Config.Treatment.bed and Config.Treatment.bed.objectModels) or {}
	for _, modelName in ipairs(type(models) == 'table' and models or {}) do
		local normalized = trimString(modelName)
		if normalized then
			hashes[#hashes + 1] = GetHashKey(normalized)
		end
	end

	treatment.objectHashes = hashes
	return hashes
end

local function resolveTreatmentBedAnchor(treatment)
	if type(treatment) ~= 'table' or not treatment.coords then
		return nil, nil
	end

	if treatment.anchorCoords and treatment.anchorHeading ~= nil then
		return treatment.anchorCoords, treatment.anchorHeading
	end

	local anchorCoords = treatment.coords
	local anchorHeading = tonumber(treatment.heading) or 340.0
	local searchRadius = math.max(0.5, tonumber(treatment.objectSearchRadius) or tonumber(Config.Treatment and Config.Treatment.bed and Config.Treatment.bed.objectSearchRadius) or 2.5)
	local bestObject = nil
	local bestDistance = nil

	for _, modelHash in ipairs(getTreatmentBedObjectHashes(treatment)) do
		local object = GetClosestObjectOfType(anchorCoords.x, anchorCoords.y, anchorCoords.z, searchRadius, modelHash, false, false, false)
		if object ~= 0 and DoesEntityExist(object) then
			local objectCoords = GetEntityCoords(object)
			local distance = #(anchorCoords - objectCoords)
			if not bestDistance or distance < bestDistance then
				bestDistance = distance
				bestObject = object
			end
		end
	end

	if bestObject and DoesEntityExist(bestObject) then
		local objectCoords = GetEntityCoords(bestObject)
		anchorCoords = vector3(objectCoords.x, objectCoords.y, objectCoords.z)
		anchorHeading = GetEntityHeading(bestObject)
		treatment.anchorEntity = bestObject
	end

	treatment.anchorCoords = anchorCoords
	treatment.anchorHeading = anchorHeading
	return anchorCoords, anchorHeading
end

local function getTreatmentPoseOffset(treatment)
	if type(treatment) ~= 'table' then
		return vector3(0.0, 0.0, 0.55)
	end

	local poseOffset = treatment.poseOffset or vector3(0.0, 0.0, 0.55)
	if trimString(treatment.poseMode) == 'anim' and treatment.animPoseOffset then
		poseOffset = treatment.animPoseOffset
	end

	local lift = tonumber(treatment.poseLift) or 0.0
	return vector3(
		tonumber(poseOffset.x) or 0.0,
		tonumber(poseOffset.y) or 0.0,
		(tonumber(poseOffset.z) or 0.55) + lift
	)
end

local function getTreatmentBedPoseCoords(treatment)
	if type(treatment) ~= 'table' or not treatment.coords then
		return nil
	end

	local anchorCoords, anchorHeading = resolveTreatmentBedAnchor(treatment)
	if not anchorCoords then
		return nil
	end

	local poseOffset = getTreatmentPoseOffset(treatment)
	local worldCoords = GetOffsetFromCoordAndHeadingInWorldCoords(
		tonumber(anchorCoords.x) or 0.0,
		tonumber(anchorCoords.y) or 0.0,
		tonumber(anchorCoords.z) or 0.0,
		tonumber(anchorHeading) or 340.0,
		tonumber(poseOffset.x) or 0.0,
		tonumber(poseOffset.y) or 0.0,
		tonumber(poseOffset.z) or 0.55
	)

	return vector3(
		tonumber(worldCoords.x) or tonumber(treatment.coords.x) or 0.0,
		tonumber(worldCoords.y) or tonumber(treatment.coords.y) or 0.0,
		tonumber(worldCoords.z) or tonumber(treatment.coords.z) or 0.0
	)
end

local function ensureTreatmentBedCollision(coords)
	if not coords then
		return
	end

	RequestCollisionAtCoord(coords.x, coords.y, coords.z)
	local timeoutAt = GetGameTimer() + 1500
	while not HasCollisionLoadedAroundEntity(PlayerPedId()) and GetGameTimer() < timeoutAt do
		RequestCollisionAtCoord(coords.x, coords.y, coords.z)
		Wait(0)
	end
end

local function playTreatmentBedAnimation(ped, treatment)
	if ped == 0 or not DoesEntityExist(ped) or type(treatment) ~= 'table' then
		return false
	end

	local poseCoords = getTreatmentBedPoseCoords(treatment)
	if not poseCoords then
		return false
	end

	local animDict = trimString(treatment.animDict) or 'dead'
	local animName = trimString(treatment.animName) or 'dead_a'
	local animFlag = math.floor(tonumber(treatment.animFlag) or 1)
	if not ensureAnimDictLoaded(animDict, 4000) then
		return false
	end

	ClearPedTasksImmediately(ped)
	TaskPlayAnimAdvanced(
		ped,
		animDict,
		animName,
		poseCoords.x,
		poseCoords.y,
		poseCoords.z,
		0.0,
		0.0,
		treatment.heading,
		8.0,
		-8.0,
		-1,
		animFlag,
		0.0,
		false,
		false,
		false,
		0,
		false
	)
	return true
end

local function startTreatmentBedScenario(ped, treatment)
	if ped == 0 or not DoesEntityExist(ped) or type(treatment) ~= 'table' or not treatment.coords then
		return false
	end

	local poseCoords = getTreatmentBedPoseCoords(treatment)
	if not poseCoords then
		return false
	end

	local scenarioName = trimString(treatment.scenarioName) or 'WORLD_HUMAN_SUNBATHE_BACK'
	ClearPedTasksImmediately(ped)
	TaskStartScenarioAtPosition(
		ped,
		scenarioName,
		poseCoords.x,
		poseCoords.y,
		poseCoords.z,
		tonumber(treatment.heading) or 340.0,
		-1,
		true,
		true
	)
	return true
end

local function isTreatmentBedPoseActive(ped, treatment)
	if ped == 0 or not DoesEntityExist(ped) or type(treatment) ~= 'table' then
		return false
	end

	if treatment.poseMode == 'scenario' then
		return IsPedUsingAnyScenario(ped)
	end

	return IsEntityPlayingAnim(ped, treatment.animDict, treatment.animName, 3)
end

local function applyTreatmentBedPose(ped, treatment)
	local preferredMode = trimString(treatment.poseMode)
	if preferredMode == 'scenario' then
		if startTreatmentBedScenario(ped, treatment) then
			return 'scenario'
		end

		if playTreatmentBedAnimation(ped, treatment) then
			return 'anim'
		end

		return nil
	end

	if preferredMode == 'anim' then
		if playTreatmentBedAnimation(ped, treatment) then
			return 'anim'
		end

		if startTreatmentBedScenario(ped, treatment) then
			return 'scenario'
		end

		return nil
	end

	if playTreatmentBedAnimation(ped, treatment) then
		return 'anim'
	end

	if startTreatmentBedScenario(ped, treatment) then
		return 'scenario'
	end

	return nil
end

local function placePedAtTreatmentBed(ped, treatment, force)
	if ped == 0 or not DoesEntityExist(ped) or type(treatment) ~= 'table' or not treatment.coords then
		return
	end

	resolveTreatmentBedAnchor(treatment)
	local targetCoords = getTreatmentBedPoseCoords(treatment)
	if not targetCoords then
		return
	end

	ensureTreatmentBedCollision(targetCoords)

	local currentCoords = GetEntityCoords(ped)
	local distance = #(currentCoords - targetCoords)
	if force == true or distance > 0.08 then
		SetEntityCoordsNoOffset(ped, targetCoords.x, targetCoords.y, targetCoords.z, false, false, false)
	end

	local _, targetHeading = resolveTreatmentBedAnchor(treatment)
	targetHeading = tonumber(targetHeading) or tonumber(treatment.heading) or 340.0
	local currentHeading = GetEntityHeading(ped)
	if force == true or math.abs(currentHeading - targetHeading) > 2.5 then
		SetEntityHeading(ped, targetHeading)
	end
end

local function raiseTreatmentBedPoseIfNeeded(ped, treatment)
	if ped == 0 or not DoesEntityExist(ped) or type(treatment) ~= 'table' then
		return false
	end

	local targetCoords = getTreatmentBedPoseCoords(treatment)
	if not targetCoords then
		return false
	end

	local currentCoords = GetEntityCoords(ped)
	local currentLift = tonumber(treatment.poseLift) or 0.0
	if currentCoords.z >= (targetCoords.z - 0.18) or currentLift >= 0.9 then
		return false
	end

	treatment.poseLift = currentLift + 0.2
	FreezeEntityPosition(ped, false)
	placePedAtTreatmentBed(ped, treatment, true)
	treatment.poseMode = applyTreatmentBedPose(ped, treatment) or treatment.poseMode
	FreezeEntityPosition(ped, true)
	return true
end

local function getTreatmentReleasePosition(treatment, exitOffset)
	if type(treatment) ~= 'table' or not treatment.coords then
		return nil, nil
	end

	local offset = exitOffset or treatment.exitOffset or vector3(1.15, 0.0, 0.0)
	local worldCoords = GetOffsetFromCoordAndHeadingInWorldCoords(
		treatment.coords.x,
		treatment.coords.y,
		treatment.coords.z,
		tonumber(treatment.heading) or 340.0,
		tonumber(offset.x) or 1.15,
		tonumber(offset.y) or 0.0,
		tonumber(offset.z) or 0.0
	)

	return vector3(
		tonumber(worldCoords.x) or treatment.coords.x,
		tonumber(worldCoords.y) or treatment.coords.y,
		tonumber(worldCoords.z) or treatment.coords.z
	), tonumber(treatment.heading) or 340.0
end

local function showHelpPrompt(message)
	BeginTextCommandDisplayHelp('STRING')
	AddTextComponentSubstringPlayerName(tostring(message or ''))
	EndTextCommandDisplayHelp(0, false, false, -1)
end

local function normalizeHashModelList(models)
	local hashes = {}
	for _, modelName in ipairs(type(models) == 'table' and models or {}) do
		local normalized = trimString(modelName)
		if normalized then
			hashes[GetHashKey(normalized)] = true
		end
	end

	return hashes
end

local function getAllowedAmbulanceHashes()
	return normalizeHashModelList(Config.Transport and Config.Transport.allowedVehicleModels)
end

local function getPatientStatus(playerId, serverId)
	local playerState = Player(serverId) and Player(serverId).state or nil
	local override = patientStatusByServerId[serverId] or {}
	return {
		isCollapsed = playerState and (playerState.lsrp_hunger_collapsed == true or playerState.lsrp_thirst_collapsed == true) or false,
		isStabilized = override.stabilized == true or (playerState and playerState.lsrp_ems_stabilized == true) or false,
		isInTransport = override.inTransport == true or (playerState and playerState.lsrp_ems_in_transport == true) or false,
		isEscorted = override.escorted == true or (playerState and playerState.lsrp_ems_escorted == true) or false,
		isInTreatment = override.inTreatment == true or (playerState and playerState.lsrp_ems_in_treatment == true) or false,
		stage = trimString(override.stage) or trimString(playerState and playerState.lsrp_ems_stage)
	}
end

local function stopEscortTasks()
	local playerPed = PlayerPedId()
	if playerPed ~= 0 and DoesEntityExist(playerPed) then
		DetachEntity(playerPed, true, false)
	end
end

local function ensureEscortAttachThread()
	CreateThread(function()
		while activeEscort and activeEscort.asPatient == true do
			Wait(0)
			local playerPed = PlayerPedId()
			if playerPed == 0 or not DoesEntityExist(playerPed) then
				goto continue
			end

			if IsPedInAnyVehicle(playerPed, false) then
				DetachEntity(playerPed, true, false)
				goto continue
			end

			local medicPlayerId = GetPlayerFromServerId(tonumber(activeEscort.medicSrc) or -1)
			if medicPlayerId == -1 then
				stopEscortTasks()
				goto continue
			end

			local medicPed = GetPlayerPed(medicPlayerId)
			if medicPed == 0 or not DoesEntityExist(medicPed) then
				stopEscortTasks()
				goto continue
			end

			if IsPedInAnyVehicle(medicPed, false) then
				DetachEntity(playerPed, true, false)
				goto continue
			end

			local offset = Config.Transport and Config.Transport.escortAttachOffset or vector3(0.54, 0.44, 0.0)
			local attachBone = math.floor(tonumber(Config.Transport and Config.Transport.escortAttachBone) or 11816)
			local maxDistance = math.max(5.0, tonumber(Config.Transport and Config.Transport.escortMaxDistance) or 22.0)
			local distance = #(GetEntityCoords(playerPed) - GetEntityCoords(medicPed))
			if distance > maxDistance then
				stopEscortTasks()
				Framework.notify('You lost your escort. Stay closer to the EMS responder.', 'warning')
				goto continue
			end

			if not IsEntityAttachedToEntity(playerPed, medicPed) then
				AttachEntityToEntity(
					playerPed,
					medicPed,
					attachBone,
					tonumber(offset.x) or 0.54,
					tonumber(offset.y) or 0.44,
					tonumber(offset.z) or 0.0,
					0.0,
					0.0,
					0.0,
					false,
					false,
					false,
					false,
					2,
					true
				)
			end

			::continue::
		end

		stopEscortTasks()
	end)
end

local function isAllowedAmbulance(vehicle)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return false
	end

	local allowedHashes = getAllowedAmbulanceHashes()
	return allowedHashes[GetEntityModel(vehicle)] == true
end

local function findNearestAmbulance(originCoords, maxDistance)
	local bestVehicle = nil
	local bestDistance = maxDistance or 10.0

	for _, vehicle in ipairs(GetGamePool('CVehicle')) do
		if DoesEntityExist(vehicle) and isAllowedAmbulance(vehicle) then
			local distance = #(originCoords - GetEntityCoords(vehicle))
			if distance <= bestDistance then
				bestVehicle = vehicle
				bestDistance = distance
			end
		end
	end

	return bestVehicle, bestDistance
end

local function getFreePassengerSeat(vehicle)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return nil
	end

	local preferredSeats = type(Config.Transport and Config.Transport.preferredPatientSeats) == 'table' and Config.Transport.preferredPatientSeats or {}
	local checkedSeats = {}
	for _, seatIndex in ipairs(preferredSeats) do
		local normalizedSeatIndex = math.floor(tonumber(seatIndex) or -999)
		checkedSeats[normalizedSeatIndex] = true
		if normalizedSeatIndex >= 0 and IsVehicleSeatFree(vehicle, normalizedSeatIndex) then
			return normalizedSeatIndex
		end
	end

	local maxPassengers = math.max(1, GetVehicleMaxNumberOfPassengers(vehicle))
	for seatIndex = maxPassengers - 1, 1, -1 do
		if checkedSeats[seatIndex] ~= true and IsVehicleSeatFree(vehicle, seatIndex) then
			return seatIndex
		end
	end

	return nil
end

local function getAmbulanceLoadPoint(vehicle)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return nil
	end

	local offset = Config.Transport and Config.Transport.loadPointOffset or vector3(0.0, -4.1, 0.0)
	local worldCoords = GetOffsetFromEntityInWorldCoords(
		vehicle,
		tonumber(offset.x) or 0.0,
		tonumber(offset.y) or -4.1,
		tonumber(offset.z) or 0.0
	)

	return vector3(
		tonumber(worldCoords.x) or 0.0,
		tonumber(worldCoords.y) or 0.0,
		tonumber(worldCoords.z) or 0.0
	)
end

local function findNearbyAmbulanceLoad(originCoords, maxVehicleDistance)
	local nearestAmbulance = findNearestAmbulance(originCoords, maxVehicleDistance)
	if not nearestAmbulance then
		return nil, nil, nil
	end

	local seatIndex = getFreePassengerSeat(nearestAmbulance)
	if seatIndex == nil then
		return nil, nil, nil
	end

	local loadPoint = getAmbulanceLoadPoint(nearestAmbulance)
	if not loadPoint then
		return nil, nil, nil
	end

	local loadRadius = math.max(1.0, tonumber(Config.Transport and Config.Transport.loadPointRadius) or 3.25)
	local localOffset = GetOffsetFromEntityGivenWorldCoords(nearestAmbulance, originCoords.x, originCoords.y, originCoords.z)
	local halfWidth = math.max(1.0, tonumber(Config.Transport and Config.Transport.loadZoneHalfWidth) or 2.2)
	local rearMin = math.max(0.0, tonumber(Config.Transport and Config.Transport.loadZoneRearMin) or 1.0)
	local rearMax = math.max(rearMin + 0.5, tonumber(Config.Transport and Config.Transport.loadZoneRearMax) or 6.0)
	local inRearZone = math.abs(tonumber(localOffset.x) or 0.0) <= halfWidth
		and (tonumber(localOffset.y) or 0.0) <= -rearMin
		and math.abs(tonumber(localOffset.y) or 0.0) <= rearMax
	local nearRearPoint = #(originCoords - loadPoint) <= loadRadius
	if not nearRearPoint and not inRearZone then
		return nil, nil, nil
	end

	return nearestAmbulance, seatIndex, loadPoint
end

local function isHospitalDropoffNearby(playerCoords)
	local dropoff = Config.Transport and Config.Transport.dropoff or nil
	if type(dropoff) ~= 'table' or not dropoff.coords then
		return false
	end

	local radius = math.max(2.0, tonumber(dropoff.radius) or 8.0)
	return #(playerCoords - dropoff.coords) <= radius
end

local function getNearbyPatient()
	local playerPed = PlayerPedId()
	if playerPed == 0 or not DoesEntityExist(playerPed) then
		return nil
	end

	local playerCoords = GetEntityCoords(playerPed)
	local reviveRange = tonumber(Config.Revive and Config.Revive.range) or 2.5
	local stabilizeRange = tonumber(Config.Stabilize and Config.Stabilize.range) or 2.5
	local transportRange = tonumber(Config.Transport and Config.Transport.range) or 3.0
	local maxRange = math.max(reviveRange, stabilizeRange, transportRange)
	local stabilizeThreshold = math.max(101, math.floor(tonumber(Config.Stabilize and Config.Stabilize.minHealthThreshold) or 175))
	local bestCandidate = nil

	for _, playerId in ipairs(GetActivePlayers()) do
		if playerId ~= PlayerId() then
			local targetPed = GetPlayerPed(playerId)
			if targetPed ~= 0 and DoesEntityExist(targetPed) then
				local serverId = GetPlayerServerId(playerId)
				local status = getPatientStatus(playerId, serverId)
				local isCollapsed = status.isCollapsed
				local isStabilized = status.isStabilized
				local isInTransport = status.isInTransport
				local isEscorted = status.isEscorted
				local isInTreatment = status.isInTreatment
				local targetCoords = GetEntityCoords(targetPed)
				local distance = #(playerCoords - targetCoords)
				if distance <= maxRange and isInTreatment ~= true then
					local action = nil
					local vehicleNetId = nil
					local seatIndex = nil
					if IsEntityDead(targetPed) or IsPedFatallyInjured(targetPed) or isCollapsed then
						if isStabilized and not isInTransport then
							local nearestAmbulance, availableSeat = nil, nil
							if isEscorted then
								nearestAmbulance, availableSeat = findNearbyAmbulanceLoad(playerCoords, tonumber(Config.Transport and Config.Transport.vehicleRange) or 10.0)
							end
							if isEscorted and nearestAmbulance and availableSeat ~= nil then
								action = 'load'
								vehicleNetId = NetworkGetNetworkIdFromEntity(nearestAmbulance)
								seatIndex = availableSeat
							else
								action = 'escort'
							end
						else
							action = 'stabilize'
						end
					elseif isStabilized and not isInTransport and not IsPedInAnyVehicle(targetPed, false) then
						local nearestAmbulance, availableSeat = nil, nil
						if isEscorted then
							nearestAmbulance, availableSeat = findNearbyAmbulanceLoad(playerCoords, tonumber(Config.Transport and Config.Transport.vehicleRange) or 10.0)
						end

						if isEscorted and nearestAmbulance and availableSeat ~= nil then
							action = 'load'
							vehicleNetId = NetworkGetNetworkIdFromEntity(nearestAmbulance)
							seatIndex = availableSeat
						else
							action = 'escort'
						end
					elseif isStabilized and isEscorted then
						action = 'escort'
					elseif GetEntityHealth(targetPed) < stabilizeThreshold then
						action = 'stabilize'
					end

					if action then
						if not bestCandidate or distance < bestCandidate.distance then
							bestCandidate = {
								targetPlayerId = playerId,
								targetSrc = serverId,
								targetName = GetPlayerName(playerId) or ('ID ' .. tostring(serverId)),
								action = action,
								distance = distance,
								vehicleNetId = vehicleNetId,
								seatIndex = seatIndex,
								isEscorted = isEscorted,
								isCollapsed = isCollapsed or IsEntityDead(targetPed) or IsPedFatallyInjured(targetPed)
							}
						end
					end
				end
			end
		end
	end

	return bestCandidate
end

local function loadActionAnim()
	local anim = Config.ActionAnimation or {}
	local animDict = trimString(anim.animDict)
	if not animDict then
		return nil, nil, 49
	end

	RequestAnimDict(animDict)
	local timeoutAt = GetGameTimer() + 5000
	while not HasAnimDictLoaded(animDict) and GetGameTimer() < timeoutAt do
		Wait(0)
	end

	if not HasAnimDictLoaded(animDict) then
		return nil, nil, 49
	end

	return animDict, trimString(anim.animName), math.floor(tonumber(anim.flag) or 49)
end

local function isMedicalActionAnimationActive(playerPed, candidate)
	if playerPed == 0 or not DoesEntityExist(playerPed) or type(candidate) ~= 'table' then
		return false
	end

	if candidate.action == 'escort' or candidate.action == 'load' then
		return true
	end

	if candidate.action == 'stabilize' and candidate.isCollapsed == true then
		return IsPedUsingAnyScenario(playerPed)
	end

	local animDict, animName = loadActionAnim()
	if not animDict or not animName then
		return false
	end

	return IsEntityPlayingAnim(playerPed, animDict, animName, 3)
end

local function startMedicalActionAnimation(playerPed, candidate, durationMs)
	if candidate.action == 'escort' or candidate.action == 'load' then
		return
	end

	if candidate.action == 'stabilize' and candidate.isCollapsed == true then
		local playerCoords = GetEntityCoords(playerPed)
		local targetPlayerId = tonumber(candidate.targetPlayerId)
		local targetPed = targetPlayerId and GetPlayerPed(targetPlayerId) or 0
		if targetPed ~= 0 and DoesEntityExist(targetPed) then
			local targetCoords = GetEntityCoords(targetPed)
			local heading = GetHeadingFromVector_2d(targetCoords.x - playerCoords.x, targetCoords.y - playerCoords.y)
			SetEntityHeading(playerPed, heading)
		end
		local scenarioName = trimString(Config.Stabilize and Config.Stabilize.collapsedScenario) or 'CODE_HUMAN_MEDIC_TEND_TO_DEAD'
		TaskStartScenarioAtPosition(
			playerPed,
			scenarioName,
			playerCoords.x,
			playerCoords.y,
			playerCoords.z,
			GetEntityHeading(playerPed),
			-1,
			true,
			true
		)
		return
	end

	local animDict, animName, animFlag = loadActionAnim()
	if animDict and animName then
		TaskPlayAnim(playerPed, animDict, animName, 2.0, 2.0, durationMs, animFlag, 0.0, false, false, false)
	end
end


local function getActionDurationMs(candidate)
	local actionName = type(candidate) == 'table' and candidate.action or candidate
	if actionName == 'revive' then
		return math.max(1000, math.floor(tonumber(Config.Revive and Config.Revive.durationMs) or 5000))
	end

	if actionName == 'escort' then
		return math.max(250, math.floor(tonumber(Config.Transport and Config.Transport.escortDurationMs) or 1800))
	end

	if actionName == 'load' then
		return math.max(750, math.floor(tonumber(Config.Transport and Config.Transport.escortDurationMs) or 1800))
	end

	if actionName == 'stabilize' and type(candidate) == 'table' and candidate.isCollapsed == true then
		return math.max(5000, math.floor(tonumber(Config.Stabilize and Config.Stabilize.collapsedDurationMs) or 25000))
	end

	return math.max(1000, math.floor(tonumber(Config.Stabilize and Config.Stabilize.durationMs) or 3500))
end

local function getActionProgressLabel(actionName, targetName, isCollapsed)
	if actionName == 'escort' then
		return ('Getting %s ready to move...'):format(tostring(targetName or 'patient'))
	end

	if actionName == 'load' then
		return ('Loading %s into the ambulance...'):format(tostring(targetName or 'patient'))
	end

	if actionName == 'stabilize' and isCollapsed == true then
		return ('Checking %s\'s vitals...'):format(tostring(targetName or 'patient'))
	end

	return ('Providing medical aid to %s...'):format(tostring(targetName or 'patient'))
end

local function beginMedicalAction(candidate)
	if type(candidate) ~= 'table' or activeAction ~= nil then
		return
	end

	local playerPed = PlayerPedId()
	if playerPed == 0 or not DoesEntityExist(playerPed) then
		return
	end

	local durationMs = getActionDurationMs(candidate)

	activeAction = candidate
	activeActionUntil = GetGameTimer() + durationMs

	startMedicalActionAnimation(playerPed, candidate, durationMs)

	CreateThread(function()
		while activeAction and GetGameTimer() < activeActionUntil do
			Wait(0)
			if activeAction.action == 'stabilize' and activeAction.isCollapsed == true then
				FreezeEntityPosition(playerPed, true)
			end
			if not isMedicalActionAnimationActive(playerPed, activeAction) then
				startMedicalActionAnimation(playerPed, activeAction, math.max(250, activeActionUntil - GetGameTimer()))
			end

			DisableControlAction(0, 21, true)
			DisableControlAction(0, 22, true)
			DisableControlAction(0, 23, true)
			DisableControlAction(0, 24, true)
			DisableControlAction(0, 25, true)
			DisableControlAction(0, 30, true)
			DisableControlAction(0, 31, true)
			DisableControlAction(0, 32, true)
			DisableControlAction(0, 33, true)
			DisableControlAction(0, 34, true)
			DisableControlAction(0, 35, true)
			DisableControlAction(0, 44, true)
			DisableControlAction(0, 75, true)
			local timeLeft = math.max(0, activeActionUntil - GetGameTimer())
			showHelpPrompt(('%s %0.1fs'):format(getActionProgressLabel(activeAction.action, activeAction.targetName, activeAction.isCollapsed == true), timeLeft / 1000.0))
		end

		local completedAction = activeAction
		activeAction = nil
		activeActionUntil = 0
		FreezeEntityPosition(playerPed, false)
		if completedAction and completedAction.action ~= 'escort' and completedAction.action ~= 'load' then
			ClearPedTasks(playerPed)
		end

		if completedAction then
			TriggerServerEvent(RESOURCE_NAME .. ':server:performMedicalAction', {
				action = completedAction.action,
				targetSrc = completedAction.targetSrc,
				vehicleNetId = completedAction.vehicleNetId,
				seatIndex = completedAction.seatIndex
			})
		end
	end)
end

local function forcePedOutOfVehicleForEscort(playerPed, vehicle)
	if playerPed == 0 or not DoesEntityExist(playerPed) or vehicle == 0 or not DoesEntityExist(vehicle) then
		return
	end

	local unloadPoint = getAmbulanceLoadPoint(vehicle)
	TaskLeaveVehicle(playerPed, vehicle, 0)
	local timeoutAt = GetGameTimer() + 4000
	while IsPedInAnyVehicle(playerPed, false) and GetGameTimer() < timeoutAt do
		Wait(0)
	end

	if IsPedInAnyVehicle(playerPed, false) then
		ClearPedTasksImmediately(playerPed)
		TaskLeaveVehicle(playerPed, vehicle, 16)
		Wait(250)
	end

	if IsPedInAnyVehicle(playerPed, false) then
		SetEntityCoordsNoOffset(
			playerPed,
			unloadPoint and unloadPoint.x or GetEntityCoords(vehicle).x,
			unloadPoint and unloadPoint.y or GetEntityCoords(vehicle).y,
			(unloadPoint and unloadPoint.z or GetEntityCoords(vehicle).z) + 0.15,
			false,
			false,
			false
		)
		Wait(0)
	end

	if unloadPoint then
		SetEntityCoordsNoOffset(playerPed, unloadPoint.x, unloadPoint.y, unloadPoint.z + 0.15, false, false, false)
		SetEntityHeading(playerPed, GetEntityHeading(vehicle))
	end
end

local function isPedSeatedInVehicleSeat(ped, vehicle, seatIndex)
	if ped == 0 or not DoesEntityExist(ped) or vehicle == 0 or not DoesEntityExist(vehicle) then
		return false
	end

	return GetVehiclePedIsIn(ped, false) == vehicle and GetPedInVehicleSeat(vehicle, math.floor(seatIndex)) == ped
end

local function tryEnterTransportVehicle(playerPed, vehicle, seatIndex)
	if playerPed == 0 or not DoesEntityExist(playerPed) or vehicle == 0 or not DoesEntityExist(vehicle) then
		return false, 'No ambulance was available for transport.'
	end

	local normalizedSeatIndex = math.floor(tonumber(seatIndex) or 0)
	local loadPoint = getAmbulanceLoadPoint(vehicle)
	local heading = GetEntityHeading(vehicle)

	for attempt = 1, 4 do
		FreezeEntityPosition(playerPed, false)
		DetachEntity(playerPed, true, false)
		ClearPedTasksImmediately(playerPed)

		if loadPoint then
			SetEntityCoordsNoOffset(playerPed, loadPoint.x, loadPoint.y, loadPoint.z + 0.15, false, false, false)
			SetEntityHeading(playerPed, heading)
			Wait(100)
		end

		if not IsVehicleSeatFree(vehicle, normalizedSeatIndex) and GetPedInVehicleSeat(vehicle, normalizedSeatIndex) ~= playerPed then
			return false, 'The ambulance no longer has a free patient seat.'
		end

		TaskEnterVehicle(playerPed, vehicle, 1500, normalizedSeatIndex, 1.0, 1, 0)
		Wait(900)
		if isPedSeatedInVehicleSeat(playerPed, vehicle, normalizedSeatIndex) then
			return true
		end

		SetPedIntoVehicle(playerPed, vehicle, normalizedSeatIndex)
		Wait(100)
		if isPedSeatedInVehicleSeat(playerPed, vehicle, normalizedSeatIndex) then
			return true
		end

		TaskWarpPedIntoVehicle(playerPed, vehicle, normalizedSeatIndex)
		Wait(100)
		if isPedSeatedInVehicleSeat(playerPed, vehicle, normalizedSeatIndex) then
			return true
		end
	end

	return false, 'The patient could not be seated in the ambulance.'
end

local function runReviveEffect(payload)
	payload = type(payload) == 'table' and payload or {}
	local playerPed = PlayerPedId()
	if playerPed == 0 or not DoesEntityExist(playerPed) then
		return
	end

	TriggerEvent('lsrp_hunger:client:revive')
	TriggerEvent('lsrp_thirst:client:revive')

	if IsEntityDead(playerPed) or IsPedFatallyInjured(playerPed) then
		local pos = GetEntityCoords(playerPed)
		local heading = GetEntityHeading(playerPed)
		local spawnTable = {
			x = pos.x,
			y = pos.y,
			z = pos.z,
			heading = heading,
			skipFade = true
		}

		local ok = pcall(function()
			exports['lsrp_spawner']:spawnPlayerDirect(spawnTable)
		end)
		if not ok then
			TriggerEvent('lsrp_spawner:spawnPlayer', GetEntityModel(playerPed), pos.x, pos.y, pos.z, heading)
		end
	end

	CreateThread(function()
		Wait(250)
		local ped = PlayerPedId()
		if ped ~= 0 and DoesEntityExist(ped) then
			SetEntityHealth(ped, math.max(101, math.floor(tonumber(payload.health) or 160)))
		end
	end)
end

local function runStabilizeEffect(payload)
	payload = type(payload) == 'table' and payload or {}
	local playerPed = PlayerPedId()
	if playerPed == 0 or not DoesEntityExist(playerPed) then
		return
	end

	if payload.keepCollapsed == true then
		if IsEntityDead(playerPed) or IsPedFatallyInjured(playerPed) then
			local pos = GetEntityCoords(playerPed)
			local heading = GetEntityHeading(playerPed)
			local spawnTable = {
				x = pos.x,
				y = pos.y,
				z = pos.z,
				heading = heading,
				skipFade = true
			}

			local ok = pcall(function()
				exports['lsrp_spawner']:spawnPlayerDirect(spawnTable)
			end)
			if not ok then
				TriggerEvent('lsrp_spawner:spawnPlayer', GetEntityModel(playerPed), pos.x, pos.y, pos.z, heading)
			end
		end

		CreateThread(function()
			Wait(250)
			local ped = PlayerPedId()
			if ped ~= 0 and DoesEntityExist(ped) then
				local targetHealth = math.max(125, math.floor(tonumber(payload.health) or 175))
				SetEntityHealth(ped, math.max(GetEntityHealth(ped), targetHealth))
			end
		end)
		return
	end

	TriggerEvent('lsrp_hunger:client:revive')
	TriggerEvent('lsrp_thirst:client:revive')

	if IsEntityDead(playerPed) or IsPedFatallyInjured(playerPed) then
		return
	end

	local targetHealth = math.max(125, math.floor(tonumber(payload.health) or 175))
	SetEntityHealth(playerPed, math.max(GetEntityHealth(playerPed), targetHealth))
end

local function runHospitalTreatmentEffect(payload)
	payload = type(payload) == 'table' and payload or {}
	local playerPed = PlayerPedId()
	if playerPed == 0 or not DoesEntityExist(playerPed) then
		return
	end

	if IsPedInAnyVehicle(playerPed, false) then
		TaskLeaveVehicle(playerPed, GetVehiclePedIsIn(playerPed, false), 0)
	end

	CreateThread(function()
		Wait(1000)
		local ped = PlayerPedId()
		if ped ~= 0 and DoesEntityExist(ped) then
			SetEntityHealth(ped, math.max(150, math.floor(tonumber(payload.health) or 200)))
		end
	end)
end

local function prepareHospitalUnload(payload)
	payload = type(payload) == 'table' and payload or {}
	local playerPed = PlayerPedId()
	if playerPed == 0 or not DoesEntityExist(playerPed) then
		return
	end

	if IsPedInAnyVehicle(playerPed, false) then
		local vehicle = GetVehiclePedIsIn(playerPed, false)
		forcePedOutOfVehicleForEscort(playerPed, vehicle)
	end

	activeTransport = nil
	FreezeEntityPosition(playerPed, false)
	ClearPedTasksImmediately(playerPed)
	DetachEntity(playerPed, true, false)
	Framework.notify(('EMS is taking you inside %s.'):format(tostring(payload.medicName or 'Pillbox')), 'info')
end

local function finishBedTreatment(payload)
	payload = type(payload) == 'table' and payload or {}
	local playerPed = PlayerPedId()
	if playerPed == 0 or not DoesEntityExist(playerPed) then
		return
	end

	activeTreatment = nil
	updateTreatmentHud(nil)
	TriggerEvent('lsrp_hunger:client:revive')
	TriggerEvent('lsrp_thirst:client:revive')
	SetPedCanRagdoll(playerPed, true)
	ClearPedTasksImmediately(playerPed)
	FreezeEntityPosition(playerPed, false)
	if payload.releaseCoords then
		SetEntityCoordsNoOffset(playerPed, tonumber(payload.releaseCoords.x) or 0.0, tonumber(payload.releaseCoords.y) or 0.0, tonumber(payload.releaseCoords.z) or 0.0, false, false, false)
		if payload.releaseHeading ~= nil then
			SetEntityHeading(playerPed, tonumber(payload.releaseHeading) or 0.0)
		end
	end
	SetEntityHealth(playerPed, math.max(150, math.floor(tonumber(payload.health) or 200)))

	local message = trimString(payload.message)
	if message then
		Framework.notify(message, trimString(payload.level) or 'success')
	else
		Framework.notify('Your treatment is complete. You can get up now.', 'success')
	end
end

local function releaseFromTreatmentBed(payload)
	payload = type(payload) == 'table' and payload or {}
	if not activeTreatment then
		return
	end

	local releaseCoords, releaseHeading = getTreatmentReleasePosition(activeTreatment, payload.exitOffset)
	finishBedTreatment({
		health = math.max(150, math.floor(tonumber(payload.health) or activeTreatment.health or 200)),
		releaseCoords = releaseCoords,
		releaseHeading = releaseHeading,
		message = payload.completed == true
			and 'Your treatment is complete. You can get up now.'
			or ('%s discharged you from the treatment bed.'):format(tostring(payload.medicName or 'EMS')),
		level = payload.completed == true and 'success' or 'info'
	})
end

local function placeOnTreatmentBed(payload)
	payload = type(payload) == 'table' and payload or {}
	local playerPed = PlayerPedId()
	if playerPed == 0 or not DoesEntityExist(playerPed) then
		return
	end

	local coords = payload.coords
	if not coords then
		return
	end

	if IsPedInAnyVehicle(playerPed, false) then
		TaskLeaveVehicle(playerPed, GetVehiclePedIsIn(playerPed, false), 0)
		Wait(1000)
	end

	ClearPedTasksImmediately(playerPed)
	SetPedCanRagdoll(playerPed, false)

	local durationMs = math.max(1000, math.floor(tonumber(payload.durationMs) or 300000))
	local endTime = GetGameTimer() + durationMs
	local currentHealth = math.floor(tonumber(GetEntityHealth(playerPed)) or 0)
	activeTreatment = {
		endTime = endTime,
		coords = vector3(tonumber(coords.x) or 353.65, tonumber(coords.y) or -584.50, tonumber(coords.z) or 44.05),
		poseOffset = payload.poseOffset or vector3(0.0, 0.0, 0.55),
		animPoseOffset = payload.animPoseOffset or payload.poseOffset or vector3(0.0, 0.0, 0.7),
		heading = tonumber(payload.heading) or 340.0,
		exitOffset = payload.exitOffset or vector3(1.15, 0.0, 0.0),
		animDict = trimString(payload.animDict) or 'dead',
		animName = trimString(payload.animName) or 'dead_a',
		animFlag = math.floor(tonumber(payload.animFlag) or 1),
		poseMode = trimString(payload.poseMode) or 'scenario',
		objectSearchRadius = tonumber(payload.objectSearchRadius) or tonumber(Config.Treatment and Config.Treatment.bed and Config.Treatment.bed.objectSearchRadius) or 2.5,
		objectModels = payload.objectModels or (Config.Treatment and Config.Treatment.bed and Config.Treatment.bed.objectModels) or {},
		poseLift = 0.0,
		scenarioName = trimString(payload.scenarioName) or 'WORLD_HUMAN_SUNBATHE_BACK',
		startHealth = math.max(101, math.floor(tonumber(payload.startHealth) or currentHealth or 150)),
		health = math.max(150, math.floor(tonumber(payload.health) or 200)),
		hudLabel = trimString(payload.hudLabel) or 'Treatment',
		dischargePrompt = trimString(payload.dischargePrompt) or 'Press ~INPUT_CONTEXT~ to stand up',
		readyForDischarge = false,
		readyRequested = false,
		dischargeRequested = false
	}
	placePedAtTreatmentBed(playerPed, activeTreatment, true)
	activeTreatment.poseMode = applyTreatmentBedPose(playerPed, activeTreatment)
	FreezeEntityPosition(playerPed, true)
	updateTreatmentHud({
		visible = true,
		label = activeTreatment.hudLabel,
		remainingMs = durationMs,
		percent = 100
	})
	CreateThread(function()
		while activeTreatment do
			Wait(0)
			local ped = PlayerPedId()
			if ped ~= 0 and DoesEntityExist(ped) then
				DisableControlAction(0, 21, true)
				DisableControlAction(0, 22, true)
				DisableControlAction(0, 23, true)
				DisableControlAction(0, 24, true)
				DisableControlAction(0, 25, true)
				DisableControlAction(0, 30, true)
				DisableControlAction(0, 31, true)
				DisableControlAction(0, 32, true)
				DisableControlAction(0, 33, true)
				DisableControlAction(0, 34, true)
				DisableControlAction(0, 35, true)
				DisableControlAction(0, 44, true)
				DisableControlAction(0, 140, true)
				DisableControlAction(0, 141, true)
				DisableControlAction(0, 142, true)
				DisableControlAction(0, 143, true)
				DisableControlAction(0, 75, true)
				DisableControlAction(0, 200, true)
				if not isTreatmentBedPoseActive(ped, activeTreatment) then
					FreezeEntityPosition(ped, false)
					placePedAtTreatmentBed(ped, activeTreatment, true)
					activeTreatment.poseMode = applyTreatmentBedPose(ped, activeTreatment)
				end

				raiseTreatmentBedPoseIfNeeded(ped, activeTreatment)

				if isTreatmentBedPoseActive(ped, activeTreatment) then
					FreezeEntityPosition(ped, true)
				else
					placePedAtTreatmentBed(ped, activeTreatment, false)
				end
			end

			local now = GetGameTimer()
			if activeTreatment.readyForDischarge == true then
				if ped ~= 0 and DoesEntityExist(ped) then
					SetEntityHealth(ped, math.max(math.floor(tonumber(activeTreatment.health) or 200), GetEntityHealth(ped)))
				end
				updateTreatmentHud(nil)
				showHelpPrompt(activeTreatment.dischargePrompt or 'Press ~INPUT_CONTEXT~ to stand up')
				local interactionControl = math.floor(tonumber(Config.InteractionKey) or 38)
				if activeTreatment.dischargeRequested ~= true
					and (IsControlJustPressed(0, interactionControl) or IsDisabledControlJustPressed(0, interactionControl)) then
					activeTreatment.dischargeRequested = true
					TriggerServerEvent(RESOURCE_NAME .. ':server:completeTreatment')
				end
			elseif (activeTreatment.lastHudUpdateAt or 0) <= (now - 250) then
				activeTreatment.lastHudUpdateAt = now
				local remainingMs = math.max(0, activeTreatment.endTime - now)
				local percent = math.floor((remainingMs / durationMs) * 100.0 + 0.5)
				local elapsedMs = math.max(0, durationMs - remainingMs)
				local completionRatio = math.max(0.0, math.min(1.0, elapsedMs / durationMs))
				local targetHealth = math.floor((activeTreatment.startHealth + ((activeTreatment.health - activeTreatment.startHealth) * completionRatio)) + 0.5)
				if ped ~= 0 and DoesEntityExist(ped) then
					SetEntityHealth(ped, math.max(GetEntityHealth(ped), targetHealth))
				end
				updateTreatmentHud({
					visible = true,
					label = activeTreatment.hudLabel,
					remainingMs = remainingMs,
					percent = percent
				})
				if remainingMs <= 0 and activeTreatment.readyRequested ~= true then
					activeTreatment.readyRequested = true
					TriggerServerEvent(RESOURCE_NAME .. ':server:treatmentTimerComplete')
				end
			end
		end
	end)
	Framework.notify(('You were checked in by %s and placed on a treatment bed.'):format(tostring(payload.medicName or 'EMS')), 'info')
end

local function enterTransportVehicle(payload)
	payload = type(payload) == 'table' and payload or {}
	local requestId = trimString(payload.requestId)
	local vehicleNetId = tonumber(payload.vehicleNetId)
	local seatIndex = tonumber(payload.seatIndex)
	if not requestId or not vehicleNetId or seatIndex == nil then
		TriggerServerEvent(RESOURCE_NAME .. ':server:confirmTransportLoad', {
			requestId = requestId,
			ok = false,
			error = 'Transport data was incomplete.'
		})
		return
	end

	local vehicle = NetworkGetEntityFromNetworkId(math.floor(vehicleNetId))
	local playerPed = PlayerPedId()
	if vehicle == 0 or not DoesEntityExist(vehicle) or not isAllowedAmbulance(vehicle) then
		TriggerServerEvent(RESOURCE_NAME .. ':server:confirmTransportLoad', {
			requestId = requestId,
			ok = false,
			error = 'No ambulance was available for transport.'
		})
		return
	end

	if not IsVehicleSeatFree(vehicle, math.floor(seatIndex)) then
		TriggerServerEvent(RESOURCE_NAME .. ':server:confirmTransportLoad', {
			requestId = requestId,
			ok = false,
			error = 'The ambulance no longer has a free patient seat.'
		})
		return
	end

	activeEscort = nil
	stopEscortTasks()
	FreezeEntityPosition(playerPed, false)
	ClearPedTasksImmediately(playerPed)
	DetachEntity(playerPed, true, false)

	local success, errorMessage = tryEnterTransportVehicle(playerPed, vehicle, seatIndex)
	if not success then
		TriggerServerEvent(RESOURCE_NAME .. ':server:confirmTransportLoad', {
			requestId = requestId,
			ok = false,
			error = errorMessage or 'The patient could not enter the ambulance.'
		})
		return
	end

	activeTransport = {
		vehicleNetId = math.floor(vehicleNetId),
		asPatient = true
	}
	TriggerServerEvent(RESOURCE_NAME .. ':server:confirmTransportLoad', {
		requestId = requestId,
		ok = true
	})
	Framework.notify(('EMS loaded you into the ambulance. Stay inside until you reach the hospital.'), 'info')
end

local function isInteractionJustPressed()
	local control = math.floor(tonumber(Config.InteractionKey) or 38)
	return IsControlJustPressed(0, control) or IsDisabledControlJustPressed(0, control)
end

local function isEmsEmployee()
	local playerState = LocalPlayer and LocalPlayer.state
	return playerState and playerState.lsrp_job == Config.JobId or false
end

local function isEmsOnDuty()
	local playerState = LocalPlayer and LocalPlayer.state
	return playerState and playerState.lsrp_job == Config.JobId and playerState.lsrp_job_duty == true or false
end

local function createBlip()
	local blipConfig = Config.Blip
	if type(blipConfig) ~= 'table' or blipConfig.enabled == false or not blipConfig.coords then
		return
	end

	local blip = AddBlipForCoord(blipConfig.coords.x, blipConfig.coords.y, blipConfig.coords.z)
	SetBlipSprite(blip, math.floor(tonumber(blipConfig.sprite) or 61))
	SetBlipDisplay(blip, 4)
	SetBlipScale(blip, tonumber(blipConfig.scale) or 0.82)
	SetBlipColour(blip, math.floor(tonumber(blipConfig.color) or 1))
	SetBlipAsShortRange(blip, true)
	BeginTextCommandSetBlipName('STRING')
	AddTextComponentSubstringPlayerName(trimString(blipConfig.label) or 'EMS Station')
	EndTextCommandSetBlipName(blip)
end

RegisterNetEvent(RESOURCE_NAME .. ':client:dutyResult', function(payload)
	payload = type(payload) == 'table' and payload or {}
	if payload.message then
		Framework.notify(payload.message, payload.ok == true and 'success' or 'error')
	end
end)

RegisterNetEvent(RESOURCE_NAME .. ':client:notify', function(message, level)
	Framework.notify(message, level)
end)

RegisterNetEvent(RESOURCE_NAME .. ':client:receiveRevive', function(payload)
	runReviveEffect(payload)
end)

RegisterNetEvent(RESOURCE_NAME .. ':client:receiveStabilize', function(payload)
	runStabilizeEffect(payload)
end)

RegisterNetEvent(RESOURCE_NAME .. ':client:enterTransportVehicle', function(payload)
	enterTransportVehicle(payload)
end)

RegisterNetEvent(RESOURCE_NAME .. ':client:transportStarted', function(payload)
	payload = type(payload) == 'table' and payload or {}
	activeEscort = nil
	stopEscortTasks()
	if payload.targetSrc then
		patientStatusByServerId[tonumber(payload.targetSrc)] = {
			stabilized = true,
			inTransport = true,
			escorted = false,
			stage = Config.Stages and Config.Stages.IN_TRANSPORT or 'in_transport'
		}
	end
	activeTransport = {
		targetSrc = tonumber(payload.targetSrc),
		targetName = trimString(payload.targetName),
		vehicleNetId = tonumber(payload.vehicleNetId),
		asPatient = payload.asPatient == true,
		medicName = trimString(payload.medicName)
	}
	if activeTransport.asPatient == true and activeTransport.medicName then
		Framework.notify(('EMS transport in progress with %s.'):format(activeTransport.medicName), 'info')
	end
end)

RegisterNetEvent(RESOURCE_NAME .. ':client:transportCleared', function()
	local targetSrc = activeTransport and activeTransport.asPatient ~= true and tonumber(activeTransport.targetSrc) or nil
	activeTransport = nil
	if targetSrc then
		patientStatusByServerId[targetSrc] = nil
	end
end)

RegisterNetEvent(RESOURCE_NAME .. ':client:updatePatientStatus', function(payload)
	payload = type(payload) == 'table' and payload or {}
	local targetSrc = tonumber(payload.targetSrc)
	if not targetSrc then
		return
	end

	patientStatusByServerId[targetSrc] = {
		stabilized = payload.stabilized == true,
		inTransport = payload.inTransport == true,
		escorted = payload.escorted == true,
		inTreatment = payload.inTreatment == true,
		stage = trimString(payload.stage)
	}
end)

RegisterNetEvent(RESOURCE_NAME .. ':client:escortStarted', function(payload)
	payload = type(payload) == 'table' and payload or {}
	if payload.targetSrc then
		patientStatusByServerId[tonumber(payload.targetSrc)] = {
			stabilized = true,
			inTransport = false,
			escorted = true,
			stage = trimString(payload.stage) or (Config.Stages and Config.Stages.ESCORTED or 'escorted')
		}
	end
	activeEscort = {
		asPatient = payload.asPatient == true,
		medicSrc = tonumber(payload.medicSrc),
		medicName = trimString(payload.medicName),
		targetSrc = tonumber(payload.targetSrc),
		targetName = trimString(payload.targetName)
	}
	if activeEscort.asPatient == true then
		Framework.notify(('EMS escort started with %s. You are being moved with them.'):format(activeEscort.medicName or 'the responder'), 'info')
		ensureEscortAttachThread()
	else
		Framework.notify(('Escorting %s to the ambulance.'):format(activeEscort.targetName or 'patient'), 'info')
	end
end)

RegisterNetEvent(RESOURCE_NAME .. ':client:escortCleared', function()
	local targetSrc = activeEscort and activeEscort.asPatient ~= true and tonumber(activeEscort.targetSrc) or nil
	activeEscort = nil
	stopEscortTasks()
	if targetSrc then
		patientStatusByServerId[targetSrc] = nil
	end
end)

RegisterNetEvent(RESOURCE_NAME .. ':client:completeHospitalTransport', function(payload)
	runHospitalTreatmentEffect(payload)
	activeEscort = nil
	stopEscortTasks()
	activeTransport = nil
end)

RegisterNetEvent(RESOURCE_NAME .. ':client:prepareHospitalUnload', function(payload)
	prepareHospitalUnload(payload)
end)

RegisterNetEvent(RESOURCE_NAME .. ':client:placeOnTreatmentBed', function(payload)
	placeOnTreatmentBed(payload)
	activeEscort = nil
	stopEscortTasks()
	activeTransport = nil
	if payload and payload.targetSrc then
		patientStatusByServerId[tonumber(payload.targetSrc)] = nil
	end
end)

RegisterNetEvent(RESOURCE_NAME .. ':client:releaseFromTreatmentBed', function(payload)
	releaseFromTreatmentBed(payload)
	activeEscort = nil
	stopEscortTasks()
	activeTransport = nil
end)

RegisterNetEvent(RESOURCE_NAME .. ':client:treatmentReady', function(payload)
	payload = type(payload) == 'table' and payload or {}
	if not activeTreatment then
		return
	end

	activeTreatment.readyForDischarge = true
	activeTreatment.dischargePrompt = trimString(payload.dischargePrompt) or activeTreatment.dischargePrompt
	updateTreatmentHud(nil)
end)

AddEventHandler('onClientResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	updateTreatmentHud(nil)
	activeTreatment = nil
end)

CreateThread(function()
	createBlip()

	while true do
		local waitMs = 750
		local playerPed = PlayerPedId()

		if playerPed ~= 0 and DoesEntityExist(playerPed) then
			local playerCoords = GetEntityCoords(playerPed)
			local marker = Config.Markers and Config.Markers.duty or nil
			local checkInMarker = Config.Markers and Config.Markers.checkIn or nil
			local nearbyPatient = isEmsOnDuty() and not IsPedInAnyVehicle(playerPed, false) and getNearbyPatient() or nil
			local playerVehicle = GetVehiclePedIsIn(playerPed, false)
			local isTransportDriver = activeTransport ~= nil
				and activeTransport.asPatient ~= true
				and playerVehicle ~= 0
				and NetworkGetNetworkIdFromEntity(playerVehicle) == activeTransport.vehicleNetId
				and GetPedInVehicleSeat(playerVehicle, -1) == playerPed
			if marker and marker.coords then
				local drawDistance = tonumber(Config.DrawDistance) or 30.0
				local interactionDistance = tonumber(Config.InteractionDistance) or 2.0
				local distance = #(playerCoords - marker.coords)

				if distance <= drawDistance then
					waitMs = 0
					local color = isEmsOnDuty() and { r = 214, g = 69, b = 69 } or { r = 94, g = 176, b = 255 }
					DrawMarker(1, marker.coords.x, marker.coords.y, marker.coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.25, 1.25, 0.65, color.r, color.g, color.b, 110, false, false, 2, false, nil, nil, false)
				end

				if distance <= interactionDistance then
					if isEmsOnDuty() then
						showHelpPrompt('Press ~INPUT_CONTEXT~ to go off EMS duty')
					elseif isEmsEmployee() then
						showHelpPrompt('Press ~INPUT_CONTEXT~ to go on EMS duty')
					else
						showHelpPrompt('You must be employed by EMS to use this duty locker')
					end

					if isInteractionJustPressed() then
						if isEmsEmployee() then
							TriggerServerEvent(RESOURCE_NAME .. ':server:toggleDuty', not isEmsOnDuty())
						else
							Framework.notify('Apply for the EMS job before using the duty locker.', 'warning')
						end
						Wait(300)
					end
				end
			end

			local dropoff = Config.Transport and Config.Transport.dropoff or nil
			if isTransportDriver and type(dropoff) == 'table' and dropoff.coords then
				local radius = math.max(2.0, tonumber(dropoff.radius) or 8.0)
				local distance = #(playerCoords - dropoff.coords)
				if distance <= math.max(radius + 20.0, tonumber(Config.DrawDistance) or 30.0) then
					waitMs = 0
					local markerConfig = dropoff.marker or {}
					local markerType = math.floor(tonumber(markerConfig.type) or 1)
					local scale = markerConfig.scale or vector3(3.0, 3.0, 0.9)
					local color = markerConfig.color or { r = 214, g = 69, b = 69, a = 110 }
					DrawMarker(markerType, dropoff.coords.x, dropoff.coords.y, dropoff.coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, scale.x or 3.0, scale.y or 3.0, scale.z or 0.9, color.r or 214, color.g or 69, color.b or 69, color.a or 110, false, false, 2, false, nil, nil, false)
				end

				if distance <= radius then
					showHelpPrompt(('Press ~INPUT_CONTEXT~ to %s'):format(tostring(Config.Transport and Config.Transport.hospitalLabel or 'admit the patient at Pillbox')))
					if isInteractionJustPressed() then
						TriggerServerEvent(RESOURCE_NAME .. ':server:completeHospitalTransport')
						Wait(300)
					end
				end
			end

			if activeEscort and activeEscort.asPatient ~= true and checkInMarker and checkInMarker.coords then
				local checkInDistance = #(playerCoords - checkInMarker.coords)
				if checkInDistance <= math.max(tonumber(Config.DrawDistance) or 30.0, 20.0) then
					waitMs = 0
					DrawMarker(1, checkInMarker.coords.x, checkInMarker.coords.y, checkInMarker.coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.25, 1.25, 0.65, 65, 201, 143, 110, false, false, 2, false, nil, nil, false)
				end

				if checkInDistance <= math.max(1.5, tonumber(Config.Treatment and Config.Treatment.checkInRange) or 2.5) then
					showHelpPrompt(('Press ~INPUT_CONTEXT~ to %s'):format(tostring(Config.Treatment and Config.Treatment.checkInLabel or 'check in the escorted patient')))
					if isInteractionJustPressed() then
						TriggerServerEvent(RESOURCE_NAME .. ':server:checkInEscortedPatient')
						Wait(300)
					end
				end
			end

			if nearbyPatient and activeAction == nil then
				waitMs = 0
				local actionLabel = nearbyPatient.action == 'revive'
					and tostring(Config.Revive and Config.Revive.label or 'revive the patient')
					or nearbyPatient.action == 'load'
					and tostring(Config.Transport and Config.Transport.loadLabel or 'load the patient into the ambulance')
					or nearbyPatient.action == 'escort'
					and (nearbyPatient.isEscorted == true
						and tostring(Config.Transport and Config.Transport.releaseEscortLabel or 'release the patient')
						or tostring(Config.Transport and Config.Transport.escortLabel or 'escort the patient'))
					or tostring(nearbyPatient.isCollapsed == true and Config.Stabilize and Config.Stabilize.collapsedLabel or Config.Stabilize and Config.Stabilize.label or 'stabilize the patient')
				showHelpPrompt(('Press ~INPUT_CONTEXT~ to %s (%s)'):format(actionLabel, tostring(nearbyPatient.targetName or 'patient')))
				if isInteractionJustPressed() then
					beginMedicalAction(nearbyPatient)
					Wait(300)
				end
			end
		end

		Wait(waitMs)
	end
end)