local function debugLog(message)
	if not Config.Debug then
		return
	end

	print(('[lsrp_hacking] %s'):format(tostring(message)))
end

local HACK_ANIM_DICT = 'anim@heists@ornate_bank@hack'
local HACK_SCENE_BASE_Z = 29.20
local HACK_SCENE_Z_LIFT = 0.43
local HACK_SCENE_FORWARD_ADJUST = 0.55
local HACK_SCENE_RIGHT_ADJUST = 0.30
local PED_BAG_COMPONENT = 5
local activeHackCamera = nil
local activeHackPuzzle = nil
local vendorPed = 0
local nextVendorTalkAt = 0
local HACK_PROPS = {
	bag = 'hei_p_m_bag_var22_arm_s',
	laptop = 'hei_prop_hst_laptop',
	card = 'hei_prop_heist_card_hack_02'
}
local vendorPedSpawnPending = false

local function showFeedNotification(message)
	BeginTextCommandThefeedPost('STRING')
	AddTextComponentSubstringPlayerName(tostring(message or ''))
	EndTextCommandThefeedPostTicker(false, false)
end

local function notifyLocal(message)
	if not message or message == '' then
		return
	end

	if GetResourceState('lsrp_framework') == 'started' then
		exports['lsrp_framework']:notify(('[Hacking] %s'):format(tostring(message)), 'info')
		return
	end

	showFeedNotification(('[Hacking] %s'):format(tostring(message)))

	TriggerEvent('chat:addMessage', {
		color = { 145, 203, 255 },
		args = { 'Hacking', tostring(message) }
	})
end

local function getVendorConfig()
	return type(Config.Vendor) == 'table' and Config.Vendor or {}
end

local function getVendorCoords()
	local vendorConfig = getVendorConfig()
	local coords = vendorConfig.coords
	if type(coords) == 'vector4' or type(coords) == 'vector3' then
		return vector3(coords.x, coords.y, coords.z), tonumber(coords.w) or tonumber(coords.heading) or 0.0
	end

	if type(coords) ~= 'table' then
		return nil, 0.0
	end

	local x = tonumber(coords.x)
	local y = tonumber(coords.y)
	local z = tonumber(coords.z)
	if not x or not y or not z then
		return nil, 0.0
	end

	return vector3(x + 0.0, y + 0.0, z + 0.0), tonumber(coords.w) or tonumber(coords.heading) or 0.0
	end

local function showHelpPrompt(message)
	BeginTextCommandDisplayHelp('STRING')
	AddTextComponentSubstringPlayerName(tostring(message or ''))
	EndTextCommandDisplayHelp(0, false, true, -1)
end

local function isVendorInteractPressed()
	return IsControlJustPressed(0, 38)
		or IsDisabledControlJustPressed(0, 38)
		or IsControlJustReleased(0, 38)
		or IsDisabledControlJustReleased(0, 38)
		or IsControlPressed(0, 38)
		or IsDisabledControlPressed(0, 38)
end

local function capturePedBagVariation(ped)
	if ped == 0 or not DoesEntityExist(ped) then
		return nil
	end

	return {
		drawable = GetPedDrawableVariation(ped, PED_BAG_COMPONENT),
		texture = GetPedTextureVariation(ped, PED_BAG_COMPONENT),
		palette = GetPedPaletteVariation(ped, PED_BAG_COMPONENT)
	}
end

local function hidePedBagVariation(ped)
	if ped == 0 or not DoesEntityExist(ped) then
		return nil
	end

	local bagVariation = capturePedBagVariation(ped)
	SetPedComponentVariation(ped, PED_BAG_COMPONENT, 0, 0, 0)
	return bagVariation
end

local function restorePedBagVariation(ped, bagVariation)
	if ped == 0 or not DoesEntityExist(ped) or type(bagVariation) ~= 'table' then
		return
	end

	SetPedComponentVariation(
		ped,
		PED_BAG_COMPONENT,
		math.max(0, math.floor(tonumber(bagVariation.drawable) or 0)),
		math.max(0, math.floor(tonumber(bagVariation.texture) or 0)),
		math.max(0, math.floor(tonumber(bagVariation.palette) or 0))
	)
end

local function requestAnimDictLoaded(animDict)
	if not animDict or animDict == '' then
		return false
	end

	RequestAnimDict(animDict)
	local timeoutAt = GetGameTimer() + 5000
	while not HasAnimDictLoaded(animDict) do
		if GetGameTimer() >= timeoutAt then
			return false
		end
		Wait(0)
	end

	return true
end

local function requestModelLoaded(modelName)
	if not modelName or modelName == '' then
		return nil
	end

	local modelHash = GetHashKey(modelName)
	if modelHash == 0 or not IsModelInCdimage(modelHash) then
		return nil
	end

	RequestModel(modelHash)
	local timeoutAt = GetGameTimer() + 5000
	while not HasModelLoaded(modelHash) do
		if GetGameTimer() >= timeoutAt then
			return nil
		end
		Wait(0)
	end

	return modelHash
end

local function destroyVendorPed()
	vendorPedSpawnPending = false

	if vendorPed ~= 0 and DoesEntityExist(vendorPed) then
		DeletePed(vendorPed)
	end

	vendorPed = 0
end

local function ensureVendorPed()
	local vendorConfig = getVendorConfig()
	if vendorConfig.enabled == false then
		destroyVendorPed()
		return
	end

	if vendorPedSpawnPending then
		return
	end

	if vendorPed ~= 0 and DoesEntityExist(vendorPed) then
		return
	end

	vendorPedSpawnPending = true

	local vendorCoords, vendorHeading = getVendorCoords()
	if not vendorCoords then
		vendorPedSpawnPending = false
		return
	end

	local modelHash = requestModelLoaded(vendorConfig.model or 'g_m_y_mexgoon_01')
	if not modelHash then
		vendorPedSpawnPending = false
		debugLog('failed to load vendor ped model')
		return
	end

	vendorPed = CreatePed(4, modelHash, vendorCoords.x, vendorCoords.y, vendorCoords.z, vendorHeading, false, false)
	vendorPedSpawnPending = false
	SetModelAsNoLongerNeeded(modelHash)
	if vendorPed == 0 or not DoesEntityExist(vendorPed) then
		vendorPed = 0
		debugLog('failed to create vendor ped')
		return
	end

	SetEntityAsMissionEntity(vendorPed, true, true)
	SetEntityHeading(vendorPed, vendorHeading)
	SetEntityCoordsNoOffset(vendorPed, vendorCoords.x, vendorCoords.y, vendorCoords.z, false, false, false)
	SetBlockingOfNonTemporaryEvents(vendorPed, true)
	SetPedCanRagdoll(vendorPed, false)
	SetPedFleeAttributes(vendorPed, 0, false)
	SetEntityInvincible(vendorPed, true)
	FreezeEntityPosition(vendorPed, true)
end

local function deleteEntitySafe(entity)
	if entity and entity ~= 0 and DoesEntityExist(entity) then
		DeleteObject(entity)
	end
end

local function cleanupHackProps(entities)
	if type(entities) ~= 'table' then
		return
	end

	deleteEntitySafe(entities.bag)
	deleteEntitySafe(entities.laptop)
	deleteEntitySafe(entities.card)
end

local function normalize2d(x, y)
	local length = math.sqrt((x * x) + (y * y))
	if length < 0.001 then
		return 0.0, 1.0
	end

	return x / length, y / length
end

local function getModelHorizontalExtents(model)
	if not model or model == 0 then
		return nil
	end

	local minimum, maximum = GetModelDimensions(model)
	if not minimum or not maximum then
		return nil
	end

	return {
		minimum = minimum,
		maximum = maximum,
		x = math.max(math.abs(minimum.x), math.abs(maximum.x)),
		y = math.max(math.abs(minimum.y), math.abs(maximum.y))
	}
end

local function getAtmFaceData(atmEntity, referenceCoords, atmCoords)
	if atmEntity == 0 or not DoesEntityExist(atmEntity) or type(referenceCoords) ~= 'vector3' then
		return nil
	end

	local extents = getModelHorizontalExtents(GetEntityModel(atmEntity))
	if not extents then
		return nil
	end

	local origin = type(atmCoords) == 'vector3' and atmCoords or GetEntityCoords(atmEntity)
	local toReferenceX, toReferenceY = normalize2d(referenceCoords.x - origin.x, referenceCoords.y - origin.y)
	local forward = GetEntityForwardVector(atmEntity)
	local forwardX, forwardY = normalize2d(forward.x, forward.y)
	local rightX, rightY = forwardY, -forwardX
	local candidates = {
		{ offsetX = extents.maximum.x, offsetY = 0.0, normalX = rightX, normalY = rightY, extent = math.abs(extents.maximum.x) },
		{ offsetX = extents.minimum.x, offsetY = 0.0, normalX = -rightX, normalY = -rightY, extent = math.abs(extents.minimum.x) },
		{ offsetX = 0.0, offsetY = extents.maximum.y, normalX = forwardX, normalY = forwardY, extent = math.abs(extents.maximum.y) },
		{ offsetX = 0.0, offsetY = extents.minimum.y, normalX = -forwardX, normalY = -forwardY, extent = math.abs(extents.minimum.y) }
	}
	local bestFace = nil
	local bestAlignment = -math.huge
	local bestDistance = math.huge

	for _, candidate in ipairs(candidates) do
		local normalX, normalY = normalize2d(candidate.normalX, candidate.normalY)
		local faceCoords = GetOffsetFromEntityInWorldCoords(atmEntity, candidate.offsetX, candidate.offsetY, 0.0)
		local planarDistance = math.sqrt(((referenceCoords.x - faceCoords.x) * (referenceCoords.x - faceCoords.x)) + ((referenceCoords.y - faceCoords.y) * (referenceCoords.y - faceCoords.y)))
		local alignment = (normalX * toReferenceX) + (normalY * toReferenceY)

		if alignment > bestAlignment + 0.01 or (math.abs(alignment - bestAlignment) <= 0.01 and planarDistance < bestDistance) then
			bestAlignment = alignment
			bestDistance = planarDistance
			bestFace = {
				normalX = normalX,
				normalY = normalY,
				faceExtent = candidate.extent,
				faceCenter = vector3(faceCoords.x, faceCoords.y, faceCoords.z)
			}
		end
	end

	return bestFace
end

local function getHackApproachDirection(atmEntity, atmCoords)
	local ped = PlayerPedId()
	local pedCoords = GetEntityCoords(ped)
	local toPedX, toPedY = normalize2d(pedCoords.x - atmCoords.x, pedCoords.y - atmCoords.y)

	if atmEntity ~= 0 and DoesEntityExist(atmEntity) then
		local faceData = getAtmFaceData(atmEntity, pedCoords, atmCoords)
		if faceData then
			return faceData.normalX, faceData.normalY
		end
	end

	return toPedX, toPedY
end

local function buildHackSceneOrigin(atmCoords, atmEntity)
	local ped = PlayerPedId()
	local pedCoords = GetEntityCoords(ped)
	local faceData = atmEntity ~= 0 and DoesEntityExist(atmEntity) and getAtmFaceData(atmEntity, pedCoords, atmCoords) or nil
	local approachX, approachY = getHackApproachDirection(atmEntity, atmCoords)
	local rightX = -approachY
	local rightY = approachX
	local anchorCoords = faceData and faceData.faceCenter or atmCoords
	local desiredPedX = anchorCoords.x + (approachX * HACK_SCENE_FORWARD_ADJUST) + (rightX * HACK_SCENE_RIGHT_ADJUST)
	local desiredPedY = anchorCoords.y + (approachY * HACK_SCENE_FORWARD_ADJUST) + (rightY * HACK_SCENE_RIGHT_ADJUST)
	local desiredPedZ = pedCoords.z
	local heading = GetHeadingFromVector_2d(anchorCoords.x - desiredPedX, anchorCoords.y - desiredPedY)
	local rotation = vector3(0.0, 0.0, heading)
	local pedOffset = GetAnimInitialOffsetPosition(
		HACK_ANIM_DICT,
		'hack_enter',
		0.0,
		0.0,
		0.0,
		rotation.x,
		rotation.y,
		rotation.z,
		0,
		2
	)
	local sceneOrigin = vector3(
		desiredPedX - pedOffset.x,
		desiredPedY - pedOffset.y,
		desiredPedZ - pedOffset.z
	)

	return {
		sceneOrigin = sceneOrigin,
		rotation = rotation,
		anchorCoords = anchorCoords
	}
end

local function createHackProp(modelName, coords)
	local modelHash = requestModelLoaded(modelName)
	if not modelHash then
		return 0
	end

	local entity = CreateObject(modelHash, coords.x, coords.y, coords.z, true, true, false)
	SetModelAsNoLongerNeeded(modelHash)
	if entity ~= 0 and DoesEntityExist(entity) then
		SetEntityAsMissionEntity(entity, true, true)
	end

	return entity
end

local function destroyHackCamera()
	if activeHackCamera and DoesCamExist(activeHackCamera) then
		RenderScriptCams(false, false, 0, true, true)
		DestroyCam(activeHackCamera, false)
	end

	activeHackCamera = nil
end

local function createHackCamera()
	destroyHackCamera()

	local camCoords = GetFinalRenderedCamCoord()
	local camRot = GetFinalRenderedCamRot(2)
	local camera = CreateCamWithParams(
		'DEFAULT_SCRIPTED_CAMERA',
		camCoords.x,
		camCoords.y,
		camCoords.z,
		camRot.x,
		camRot.y,
		camRot.z,
		GetGameplayCamFov(),
		true,
		2
	)
	if not camera or camera == 0 then
		return nil
	end

	SetCamActive(camera, true)
	RenderScriptCams(true, false, 0, true, true)
	activeHackCamera = camera
	return camera
end

local function playScenePart(scene, durationMs)
	NetworkStartSynchronisedScene(scene)
	Wait(math.max(0, math.floor(tonumber(durationMs) or 0)))
	NetworkStopSynchronisedScene(scene)
end

local function getHackPuzzleConfig()
	return type(Config.HackPuzzle) == 'table' and Config.HackPuzzle or {}
end

local function buildHackPuzzleRound(nodeCount)
	local totalNodes = math.max(2, math.floor(tonumber(nodeCount) or 3))
	local nodes = {}

	for index = 1, totalNodes do
		local targetValue = math.random(0, 9)
		local currentValue = math.random(0, 9)
		if currentValue == targetValue then
			currentValue = (currentValue + math.random(1, 8)) % 10
		end

		nodes[#nodes + 1] = {
			id = index,
			target = targetValue,
			current = currentValue
		}
	end

	return nodes
end

local function buildHackPuzzlePayload()
	local puzzleConfig = getHackPuzzleConfig()
	local rounds = 3
	local roundNodeCounts = type(puzzleConfig.roundNodeCounts) == 'table' and puzzleConfig.roundNodeCounts or {}
	local payload = {
		requestId = ('%d:%d'):format(GetGameTimer(), math.random(1000, 9999)),
		timeLimitSeconds = math.max(10, math.floor(tonumber(puzzleConfig.timeLimitSeconds) or 45)),
		rounds = {}
	}

	for roundIndex = 1, rounds do
		payload.rounds[#payload.rounds + 1] = {
			index = roundIndex,
			nodes = buildHackPuzzleRound(roundNodeCounts[roundIndex] or (roundIndex + 2))
		}
	end

	return payload
end

local function hideHackPuzzle()
	activeHackPuzzle = nil
	SetNuiFocus(false, false)
	if type(SetNuiFocusKeepInput) == 'function' then
		SetNuiFocusKeepInput(false)
	end
	SendNUIMessage({ action = 'hidePuzzle' })
end

local function resolveHackPuzzle(requestId, success, errorMessage)
	if not activeHackPuzzle or tostring(requestId or '') ~= tostring(activeHackPuzzle.requestId or '') then
		return false
	end

	activeHackPuzzle.resolved = true
	activeHackPuzzle.success = success == true
	activeHackPuzzle.errorMessage = tostring(errorMessage or (success == true and '') or 'The ATM lockout tripped.')
	return true
end

local function beginHackPuzzle()
	if activeHackPuzzle then
		return nil, 'A hack is already in progress.'
	end

	local payload = buildHackPuzzlePayload()
	activeHackPuzzle = {
		requestId = payload.requestId,
		resolved = false,
		success = false,
		errorMessage = 'The ATM lockout tripped.'
	}

	SetNuiFocus(true, true)
	if type(SetNuiFocusKeepInput) == 'function' then
		SetNuiFocusKeepInput(false)
	end
	SendNUIMessage({
		action = 'showPuzzle',
		payload = payload
	})

	return activeHackPuzzle, nil
end

local function createHackScene(sceneOrigin, sceneRotation, ped, bag, laptop, card, sceneName)
	local scene = NetworkCreateSynchronisedScene(sceneOrigin.x, sceneOrigin.y, sceneOrigin.z, sceneRotation.x, sceneRotation.y, sceneRotation.z, 2, false, false, 1065353216, 0, 1.3)
	NetworkAddPedToSynchronisedScene(ped, scene, HACK_ANIM_DICT, sceneName, 1.5, -4.0, 1, 16, 1148846080, 0)
	NetworkAddEntityToSynchronisedScene(bag, scene, HACK_ANIM_DICT, ('%s_bag'):format(sceneName), 4.0, -8.0, 1)
	NetworkAddEntityToSynchronisedScene(laptop, scene, HACK_ANIM_DICT, ('%s_laptop'):format(sceneName), 4.0, -8.0, 1)
	NetworkAddEntityToSynchronisedScene(card, scene, HACK_ANIM_DICT, ('%s_card'):format(sceneName), 4.0, -8.0, 1)
	return scene
end

local function awaitHackPuzzle(ped, sceneOrigin, sceneRotation, bag, laptop, card)
	local puzzleState = beginHackPuzzle()
	if not puzzleState then
		return false, 'The hacking interface failed to open.'
	end

	while activeHackPuzzle == puzzleState and not puzzleState.resolved do
		if ped == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) or IsPedRagdoll(ped) then
			resolveHackPuzzle(puzzleState.requestId, false, 'The hack was interrupted.')
			break
		end

		local loopScene = createHackScene(sceneOrigin, sceneRotation, ped, bag, laptop, card, 'hack_loop')
		NetworkStartSynchronisedScene(loopScene)

		local cycleDeadline = GetGameTimer() + 4200
		while GetGameTimer() < cycleDeadline do
			Wait(50)
			if activeHackPuzzle ~= puzzleState or puzzleState.resolved then
				break
			end
			if ped == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) or IsPedRagdoll(ped) then
				resolveHackPuzzle(puzzleState.requestId, false, 'The hack was interrupted.')
				break
			end
		end

		NetworkStopSynchronisedScene(loopScene)
	end

	local success = puzzleState.success == true
	local errorMessage = puzzleState.errorMessage
	hideHackPuzzle()
	return success, errorMessage
end

local function playHackScene(atmCoords, atmEntity)
	local ped = PlayerPedId()
	if ped == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) then
		return false, 'You cannot hack the ATM right now.'
	end

	if not requestAnimDictLoaded(HACK_ANIM_DICT) then
		return false, 'The hacking animation failed to load.'
	end

	local sceneData = buildHackSceneOrigin(atmCoords, atmEntity)
	local sceneOrigin = sceneData.sceneOrigin
	local sceneRotation = sceneData.rotation
	local pedBagVariation = nil
	local hackCamera = nil
	local pedStartPosition = GetAnimInitialOffsetPosition(
		HACK_ANIM_DICT,
		'hack_enter',
		sceneOrigin.x,
		sceneOrigin.y,
		sceneOrigin.z,
		sceneRotation.x,
		sceneRotation.y,
		sceneRotation.z,
		0,
		2
	)
	local pedStartRotation = GetAnimInitialOffsetRotation(
		HACK_ANIM_DICT,
		'hack_enter',
		sceneOrigin.x,
		sceneOrigin.y,
		sceneOrigin.z,
		sceneRotation.x,
		sceneRotation.y,
		sceneRotation.z,
		0,
		2
	)
	local bag = createHackProp(HACK_PROPS.bag, sceneOrigin)
	local laptop = createHackProp(HACK_PROPS.laptop, sceneOrigin)
	local card = createHackProp(HACK_PROPS.card, sceneOrigin)
	if bag == 0 or laptop == 0 or card == 0 then
		cleanupHackProps({ bag = bag, laptop = laptop, card = card })
		return false, 'The hacking tools could not be prepared.'
	end

	hackCamera = createHackCamera()
	pedBagVariation = hidePedBagVariation(ped)
	SetEntityCoordsNoOffset(ped, pedStartPosition.x, pedStartPosition.y, pedStartPosition.z, false, false, false)
	SetEntityRotation(ped, pedStartRotation.x, pedStartRotation.y, pedStartRotation.z, 2, true)
	FreezeEntityPosition(ped, true)

	local enterScene = createHackScene(sceneOrigin, sceneRotation, ped, bag, laptop, card, 'hack_enter')
	local exitScene = createHackScene(sceneOrigin, sceneRotation, ped, bag, laptop, card, 'hack_exit')
	local success = false
	local errorMessage = nil

	playScenePart(enterScene, 4500)
	success, errorMessage = awaitHackPuzzle(ped, sceneOrigin, sceneRotation, bag, laptop, card)
	playScenePart(exitScene, 4500)

	cleanupHackProps({ bag = bag, laptop = laptop, card = card })
	FreezeEntityPosition(ped, false)
	ClearPedTasks(ped)
	restorePedBagVariation(ped, pedBagVariation)
	if hackCamera then
		destroyHackCamera()
	end
	return success, errorMessage
end

local function isExteriorAtmLocation(coords)
	if type(coords) ~= 'vector3' then
		return false
	end

	return GetInteriorAtCoords(coords.x, coords.y, coords.z) == 0
end

local function isUsableExteriorAtm(atmCoords, playerCoords)
	if Config.ExteriorOnlyAtms ~= true then
		return true
	end

	if isExteriorAtmLocation(atmCoords) then
		return true
	end

	return isExteriorAtmLocation(playerCoords)
end

local function getAtmInteractionDistance(playerCoords, atmEntity, atmCoords)
	if type(playerCoords) ~= 'vector3' or type(atmCoords) ~= 'vector3' then
		return math.huge
	end

	local directDistance = #(playerCoords - atmCoords)
	if atmEntity == 0 or not DoesEntityExist(atmEntity) then
		return directDistance
	end

	local faceData = getAtmFaceData(atmEntity, playerCoords, atmCoords)
	if not faceData then
		return directDistance
	end

	local interactionPoint = vector3(
		faceData.faceCenter.x,
		faceData.faceCenter.y,
		atmCoords.z
	)

	return math.min(directDistance, #(playerCoords - interactionPoint))
end

local function isConfiguredAtmModel(modelHash)
	if not modelHash or modelHash == 0 then
		return false
	end

	for _, configuredModelHash in ipairs(Config.AtmModels or {}) do
		if modelHash == configuredModelHash then
			return true
		end
	end

	return false
end

local function getNearestAtm(maxDistance)
	local ped = PlayerPedId()
	if ped == 0 or not DoesEntityExist(ped) then
		return nil
	end

	local playerCoords = GetEntityCoords(ped)
	local interactDistance = math.max(0.5, tonumber(maxDistance) or tonumber(Config.AtmUseDistance) or 1.8)
	local scanRadius = math.max(interactDistance, tonumber(Config.AtmScanRadius) or 5.0)
	local nearestAtm = nil
	local nearestDistance = interactDistance + 0.001
	local objectPool = GetGamePool('CObject') or {}

	for _, atmObject in ipairs(objectPool) do
		if atmObject ~= 0 and DoesEntityExist(atmObject) and isConfiguredAtmModel(GetEntityModel(atmObject)) then
			local atmCoords = GetEntityCoords(atmObject)
			local coarseDistance = #(playerCoords - atmCoords)
			if coarseDistance <= scanRadius then
				local distance = getAtmInteractionDistance(playerCoords, atmObject, atmCoords)
				local isValidAtm = isUsableExteriorAtm(atmCoords, playerCoords)
				if isValidAtm and distance <= interactDistance and distance < nearestDistance then
					nearestDistance = distance
					nearestAtm = {
						entity = atmObject,
						coords = atmCoords,
						distance = distance
					}
				end
			end
		end
	end

	return nearestAtm
end

exports('getNearestAtm', function(maxDistance)
	return getNearestAtm(maxDistance)
end)

RegisterNUICallback('hackPuzzleComplete', function(data, cb)
	resolveHackPuzzle(data and data.requestId, true, nil)
	cb({ ok = true })
end)

RegisterNUICallback('hackPuzzleFail', function(data, cb)
	resolveHackPuzzle(data and data.requestId, false, data and data.error)
	cb({ ok = true })
end)

local function performAtmHack(context)
	if type(context) ~= 'table' then
		return false, 'The hacking device did not initialize correctly.'
	end

	local atmEntity = tonumber(context.atm) or 0
	local atmCoords = vector3(
		tonumber(context.x) or 0.0,
		tonumber(context.y) or 0.0,
		tonumber(context.z) or 0.0
	)
	if atmEntity ~= 0 and DoesEntityExist(atmEntity) then
		atmCoords = GetEntityCoords(atmEntity)
	end

	local ped = PlayerPedId()
	local playerCoords = atmCoords
	if ped ~= 0 and DoesEntityExist(ped) then
		playerCoords = GetEntityCoords(ped)
	end

	if not isUsableExteriorAtm(atmCoords, playerCoords) then
		debugLog(('blocked indoor ATM hack at %.2f, %.2f, %.2f'):format(
			atmCoords.x,
			atmCoords.y,
			atmCoords.z
		))
		return false, 'Stand next to an outdoor ATM to use the hacking device.'
	end

	debugLog(('device used near ATM at %.2f, %.2f, %.2f'):format(
		atmCoords.x,
		atmCoords.y,
		atmCoords.z
	))

	local hackSucceeded, hackError = playHackScene(atmCoords, atmEntity)
	if hackSucceeded ~= true then
		return false, hackError or 'The ATM lockout tripped.'
	end

	TriggerServerEvent('lsrp_hacking:server:completeAtmHack', {
		x = atmCoords.x,
		y = atmCoords.y,
		z = atmCoords.z
	})

	return true, nil
end

exports('startAtmHack', function(context)
	return performAtmHack(context)
end)

RegisterNetEvent('lsrp_hacking:client:deviceUsed', function(context)
	local success, errorMessage = performAtmHack(context)
	if success ~= true and errorMessage and errorMessage ~= '' then
		notifyLocal(errorMessage)
	end
end)

RegisterNetEvent('lsrp_hacking:client:notify', function(message)
	notifyLocal(message)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	hideHackPuzzle()
	ensureVendorPed()
	debugLog('client started')
end)

CreateThread(function()
	while true do
		local waitMs = 1000
		local vendorConfig = getVendorConfig()
		if vendorConfig.enabled ~= false then
			ensureVendorPed()

			local playerPed = PlayerPedId()
			if playerPed ~= 0 and DoesEntityExist(playerPed) and not IsPedInAnyVehicle(playerPed, false) then
				local vendorCoords = nil
				if vendorPed ~= 0 and DoesEntityExist(vendorPed) then
					vendorCoords = GetEntityCoords(vendorPed)
				else
					vendorCoords = select(1, getVendorCoords())
				end

				if vendorCoords then
					local playerCoords = GetEntityCoords(playerPed)
					local distance = #(playerCoords - vendorCoords)
					if distance <= math.max(1.0, tonumber(vendorConfig.drawDistance) or 18.0) then
						waitMs = 0
						if distance <= math.max(1.0, tonumber(vendorConfig.interactDistance) or 2.0) then
							showHelpPrompt(tostring(vendorConfig.prompt or 'Press ~INPUT_CONTEXT~ to talk'))
							if GetGameTimer() >= nextVendorTalkAt and isVendorInteractPressed() then
								nextVendorTalkAt = GetGameTimer() + 900
								TriggerServerEvent('lsrp_hacking:server:talkToVendor')
							end
						end
					end
				end
			end
		end

		Wait(waitMs)
	end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	hideHackPuzzle()
	destroyVendorPed()
	destroyHackCamera()
end)