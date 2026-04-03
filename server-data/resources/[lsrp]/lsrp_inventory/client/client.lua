local uiOpen = false
local latestInventory = {
	slots = 0,
	maxWeight = 0,
	items = {}
}
local latestTransferTarget = nil
local latestStashTarget = nil
local worldDrops = {}
local latestNearbyPlayers = {}
local useInProgress = false
local activeUseToken = nil
local activeUseContext = nil
local activeUseProp = nil

local function getActiveTarget()
	return latestStashTarget or latestTransferTarget
end

local function notifyLocal(message)
	if not message or message == '' then
		return
	end
	if mode == 'none' then
		return true, nil
	end


	TriggerEvent('chat:addMessage', {
		args = { ('^3[Inventory]^7 %s'):format(tostring(message)) }
	})
end

local function normalizeInventoryPayload(raw)
	raw = type(raw) == 'table' and raw or {}
	return {
		slots = math.max(1, math.floor(tonumber(raw.slots) or 1)),
		maxWeight = math.max(0, math.floor(tonumber(raw.maxWeight) or 0)),
		items = type(raw.items) == 'table' and raw.items or {}
	}
end

local function getTransferRange()
	return math.max(1.0, tonumber(Config and Config.Inventory and Config.Inventory.transferRange) or 4.0)
end

local function getInventoryItemBySlot(slot)
	local normalizedSlot = math.floor(tonumber(slot) or 0)
	if normalizedSlot < 1 then
		return nil
	end

	for _, item in ipairs(latestInventory.items or {}) do
		if math.floor(tonumber(item.slot) or 0) == normalizedSlot then
			return item
		end
	end

	return nil
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
		Citizen.Wait(0)
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

local function clearUseProp()
	if activeUseProp and DoesEntityExist(activeUseProp) then
		DeleteObject(activeUseProp)
	end

	activeUseProp = nil
end

local function attachUseProp(propData)
	clearUseProp()

	if type(propData) ~= 'table' then
		return true
	end

	local modelHash = requestModelLoaded(tostring(propData.model or ''))
	if not modelHash then
		return false
	end

	local ped = PlayerPedId()
	if ped == 0 or not DoesEntityExist(ped) then
		SetModelAsNoLongerNeeded(modelHash)
		return false
	end

	local offsetX = tonumber(propData.offset and propData.offset.x) or 0.0
	local offsetY = tonumber(propData.offset and propData.offset.y) or 0.0
	local offsetZ = tonumber(propData.offset and propData.offset.z) or 0.0
	local rotationX = tonumber(propData.rotation and propData.rotation.x) or 0.0
	local rotationY = tonumber(propData.rotation and propData.rotation.y) or 0.0
	local rotationZ = tonumber(propData.rotation and propData.rotation.z) or 0.0
	local groundLift = tonumber(propData.groundLift) or 0.0
	local attachToPed = propData.attachToPed ~= false

	local spawnCoords = GetEntityCoords(ped)
	if not attachToPed then
		spawnCoords = GetOffsetFromEntityInWorldCoords(ped, offsetX, offsetY, offsetZ)
	end

	local propEntity = CreateObject(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, true, true, false)
	SetModelAsNoLongerNeeded(modelHash)
	if propEntity == 0 or not DoesEntityExist(propEntity) then
		return false
	end

	SetEntityAsMissionEntity(propEntity, true, true)

	if not attachToPed then
		SetEntityRotation(propEntity, rotationX, rotationY, GetEntityHeading(ped) + rotationZ, 2, true)
		PlaceObjectOnGroundProperly(propEntity)
		if groundLift ~= 0.0 then
			local placedCoords = GetEntityCoords(propEntity)
			SetEntityCoordsNoOffset(propEntity, placedCoords.x, placedCoords.y, placedCoords.z + groundLift, false, false, false)
		end
		FreezeEntityPosition(propEntity, true)
		activeUseProp = propEntity
		return true
	end

	local attachmentBone = math.floor(tonumber(propData.bone) or 57005)
	local boneIndex = attachmentBone > 0 and GetPedBoneIndex(ped, attachmentBone) or 0

	AttachEntityToEntity(
		propEntity,
		ped,
		boneIndex,
		offsetX,
		offsetY,
		offsetZ,
		rotationX,
		rotationY,
		rotationZ,
		true,
		true,
		false,
		true,
		1,
		true
	)

	activeUseProp = propEntity
	return true
end

local function playItemUseAnimation(useData)
	local ped = PlayerPedId()
	if ped == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) then
		return false, 'invalid_ped'
	end

	if useData.requireOnFoot ~= false and IsPedInAnyVehicle(ped, false) then
		return false, 'in_vehicle'
	end

	local mode = tostring(useData.mode or 'anim')
	if mode == 'none' then
		return true, nil
	end

	if mode == 'scenario' then
		local scenario = tostring(useData.scenario or '')
		if scenario == '' then
			return false, 'invalid_scenario'
		end
		TaskStartScenarioInPlace(ped, scenario, 0, true)
		if not attachUseProp(useData.prop) then
			ClearPedTasks(ped)
			return false, 'missing_prop'
		end
		return true, nil
	end

	local animDict = tostring(useData.animDict or '')
	local animName = tostring(useData.animName or '')
	if animDict == '' or animName == '' then
		return false, 'invalid_anim'
	end

	if not requestAnimDictLoaded(animDict) then
		return false, 'missing_anim_dict'
	end

	TaskPlayAnim(
		ped,
		animDict,
		animName,
		8.0,
		-8.0,
		-1,
		math.floor(tonumber(useData.flag) or 49),
		0.0,
		false,
		false,
		false
	)

	if not attachUseProp(useData.prop) then
		ClearPedTasks(ped)
		return false, 'missing_prop'
	end

	return true, nil
end

local function finishUseAnimation()
	local ped = PlayerPedId()
	if ped ~= 0 and DoesEntityExist(ped) then
		ClearPedTasks(ped)
	end
	clearUseProp()
	useInProgress = false
	activeUseToken = nil
end

local function getClosestAtm(maxDistance)
	if GetResourceState('lsrp_hacking') ~= 'started' then
		return nil
	end

	local ok, atmData = pcall(function()
		return exports['lsrp_hacking']:getNearestAtm(maxDistance)
	end)

	if not ok or type(atmData) ~= 'table' then
		return nil
	end

	local atmEntity = tonumber(atmData.entity) or 0
	if atmEntity == 0 or not DoesEntityExist(atmEntity) then
		return nil
	end

	return {
		entity = atmEntity,
		coords = atmData.coords,
		distance = tonumber(atmData.distance) or 0.0
	}
end

local function requestVehicleControl(vehicle, timeoutMs)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return false
	end

	if not NetworkGetEntityIsNetworked(vehicle) or NetworkHasControlOfEntity(vehicle) then
		return true
	end

	local timeoutAt = GetGameTimer() + math.max(0, math.floor(tonumber(timeoutMs) or 500))
	NetworkRequestControlOfEntity(vehicle)
	while GetGameTimer() < timeoutAt do
		if NetworkHasControlOfEntity(vehicle) then
			return true
		end
		Wait(0)
		NetworkRequestControlOfEntity(vehicle)
	end

	return NetworkHasControlOfEntity(vehicle)
end

local function clampNumber(value, minValue, maxValue)
	if value < minValue then
		return minValue
	end

	if value > maxValue then
		return maxValue
	end

	return value
end

local function getVehicleDistanceFromPoint(vehicle, worldPoint)
	if vehicle == 0 or not DoesEntityExist(vehicle) or type(worldPoint) ~= 'vector3' then
		return math.huge
	end

	local vehicleCoords = GetEntityCoords(vehicle)
	local bestDistance = #(worldPoint - vehicleCoords)
	local model = GetEntityModel(vehicle)
	if not model or model == 0 then
		return bestDistance
	end

	local minimum, maximum = GetModelDimensions(model)
	if not minimum or not maximum then
		return bestDistance
	end

	local localPoint = GetOffsetFromEntityGivenWorldCoords(vehicle, worldPoint.x, worldPoint.y, worldPoint.z)
	local closestX = clampNumber(localPoint.x, minimum.x, maximum.x)
	local closestY = clampNumber(localPoint.y, minimum.y, maximum.y)
	local closestZ = clampNumber(localPoint.z, minimum.z, maximum.z)
	local closestWorldPoint = GetOffsetFromEntityInWorldCoords(vehicle, closestX, closestY, closestZ)

	return math.min(bestDistance, #(worldPoint - closestWorldPoint))
end

local function getVehicleProximityDistance(vehicle, ped, playerCoords)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return math.huge
	end

	local origin = playerCoords or GetEntityCoords(ped)
	local frontProbe = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.2, 0.0)
	local sideProbe = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.6, 0.0)

	local bestDistance = getVehicleDistanceFromPoint(vehicle, origin)
	bestDistance = math.min(bestDistance, getVehicleDistanceFromPoint(vehicle, frontProbe))
	bestDistance = math.min(bestDistance, getVehicleDistanceFromPoint(vehicle, sideProbe))

	return bestDistance
end

local function findClosestVehicle(maxDistance, predicate)
	local ped = PlayerPedId()
	if ped == 0 or not DoesEntityExist(ped) then
		return 0, nil
	end

	local playerCoords = GetEntityCoords(ped)
	local searchRadius = math.max(0.0, tonumber(maxDistance) or 4.0)
	local closestVehicle = 0
	local closestValue = nil
	local closestDistance = searchRadius + 0.001
	local frontProbe = GetOffsetFromEntityInWorldCoords(ped, 0.0, math.min(searchRadius, 1.2), 0.0)

	local nativeClosestVehicle = GetClosestVehicle(playerCoords.x, playerCoords.y, playerCoords.z, searchRadius + 0.0, 0, 71)
	if nativeClosestVehicle ~= 0 and DoesEntityExist(nativeClosestVehicle) then
		local nativeDistance = getVehicleProximityDistance(nativeClosestVehicle, ped, playerCoords)
		if nativeDistance <= searchRadius then
			local matches, value = predicate(nativeClosestVehicle)
			if matches == true then
				return nativeClosestVehicle, value
			end
		end
	end

	local nativeFrontVehicle = GetClosestVehicle(frontProbe.x, frontProbe.y, frontProbe.z, searchRadius + 0.0, 0, 71)
	if nativeFrontVehicle ~= 0 and nativeFrontVehicle ~= nativeClosestVehicle and DoesEntityExist(nativeFrontVehicle) then
		local nativeDistance = getVehicleProximityDistance(nativeFrontVehicle, ped, playerCoords)
		if nativeDistance <= searchRadius then
			local matches, value = predicate(nativeFrontVehicle)
			if matches == true then
				return nativeFrontVehicle, value
			end
		end
	end

	for _, vehicle in ipairs(GetGamePool('CVehicle')) do
		if vehicle ~= 0 and DoesEntityExist(vehicle) then
			local distance = getVehicleProximityDistance(vehicle, ped, playerCoords)
			if distance <= searchRadius and distance < closestDistance then
				local matches, value = predicate(vehicle)
				if matches == true then
					closestVehicle = vehicle
					closestValue = value
					closestDistance = distance
				end
			end
		end
	end

	return closestVehicle, closestValue
end

local function getClosestRefuelableVehicle(maxDistance)
	if GetResourceState('lsrp_fuel') ~= 'started' then
		return 0, nil
	end

	return findClosestVehicle(maxDistance, function(vehicle)
		local okFuel, currentFuel = pcall(function()
			return exports['lsrp_fuel']:getFuel(vehicle)
		end)
		local okCapacity, tankCapacity = pcall(function()
			return exports['lsrp_fuel']:getTankCapacity(vehicle)
		end)
		if okFuel and type(currentFuel) == 'number' and okCapacity and type(tankCapacity) == 'number' then
			return true, {
				currentFuel = currentFuel,
				tankCapacity = tankCapacity
			}
		end

		return false, nil
	end)
end

local function getClosestNearbyVehicle(maxDistance)
	return findClosestVehicle(maxDistance, function(vehicle)
		return true, nil
	end)
end

local function doesVehicleNeedRepair(vehicle)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return false, nil
	end

	local engineHealth = tonumber(GetVehicleEngineHealth(vehicle)) or 1000.0
	local bodyHealth = tonumber(GetVehicleBodyHealth(vehicle)) or 1000.0
	local petrolTankHealth = tonumber(GetVehiclePetrolTankHealth(vehicle)) or 1000.0
	local isDriveable = IsVehicleDriveable(vehicle, false)
	local visiblyDamaged = false

	if type(IsVehicleDamaged) == 'function' then
		visiblyDamaged = IsVehicleDamaged(vehicle) == true
	end

	if not visiblyDamaged then
		for wheelIndex = 0, 7 do
			if IsVehicleTyreBurst(vehicle, wheelIndex, false) or IsVehicleTyreBurst(vehicle, wheelIndex, true) then
				visiblyDamaged = true
				break
			end
		end
	end

	local needsRepair = engineHealth < 995.0
		or bodyHealth < 995.0
		or petrolTankHealth < 995.0
		or not isDriveable
		or visiblyDamaged

	if not needsRepair then
		return false, {
			engineHealth = engineHealth,
			bodyHealth = bodyHealth,
			petrolTankHealth = petrolTankHealth
		}
	end

	return true, {
		engineHealth = engineHealth,
		bodyHealth = bodyHealth,
		petrolTankHealth = petrolTankHealth
	}
end

local function getClosestRepairableVehicle(maxDistance)
	return findClosestVehicle(maxDistance, function(vehicle)
		return doesVehicleNeedRepair(vehicle)
	end)
end

local function repairVehicleFully(vehicle)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return false
	end

	local hasControl = requestVehicleControl(vehicle, 2000)
	if NetworkGetEntityIsNetworked(vehicle) and not hasControl then
		return false
	end

	SetVehicleFixed(vehicle)
	SetVehicleDeformationFixed(vehicle)
	SetVehicleUndriveable(vehicle, false)
	SetVehicleEngineHealth(vehicle, 1000.0)
	SetVehicleBodyHealth(vehicle, 1000.0)
	SetVehiclePetrolTankHealth(vehicle, 1000.0)
	SetVehicleDirtLevel(vehicle, 0.0)
	SetVehicleEngineOn(vehicle, true, true, false)

	for wheelIndex = 0, 7 do
		if IsVehicleTyreBurst(vehicle, wheelIndex, false) or IsVehicleTyreBurst(vehicle, wheelIndex, true) then
			SetVehicleTyreFixed(vehicle, wheelIndex)
		end
	end

	Wait(0)

	local stillNeedsRepair = doesVehicleNeedRepair(vehicle)
	return stillNeedsRepair ~= true
end

local function buildUseEffectContext(effect)
	if type(effect) ~= 'table' then
		return nil, nil
	end

	local effectType = tostring(effect.type or '')
	if effectType == 'vehicle_refuel_amount' or effectType == 'vehicle_refuel_full' then
		local maxDistance = math.max(1.0, tonumber(effect.maxDistance) or 4.0)
		local vehicle, fuelData = getClosestRefuelableVehicle(maxDistance)
		if vehicle == 0 or type(fuelData) ~= 'table' then
			return nil, 'Stand next to a vehicle to use the gas can.'
		end

		local networkId = NetworkGetEntityIsNetworked(vehicle) and NetworkGetNetworkIdFromEntity(vehicle) or nil
		return {
			effectType = effectType,
			vehicle = vehicle,
			networkId = networkId,
			maxDistance = maxDistance,
			fuelData = {
				currentFuel = fuelData.currentFuel,
				tankCapacity = fuelData.tankCapacity
			}
		}, nil
	end

	if effectType == 'vehicle_repair_full' then
		local maxDistance = math.max(1.0, tonumber(effect.maxDistance) or 4.0)
		local vehicle = getClosestNearbyVehicle(maxDistance)
		if vehicle == 0 then
			return nil, 'Stand next to a vehicle to use the repair kit.'
		end

		local networkId = NetworkGetEntityIsNetworked(vehicle) and NetworkGetNetworkIdFromEntity(vehicle) or nil
		return {
			effectType = effectType,
			vehicle = vehicle,
			networkId = networkId,
			maxDistance = maxDistance
		}, nil
	end

	if effectType == 'atm_hacking_animation' then
		local maxDistance = math.max(0.5, tonumber(effect.maxDistance) or 1.8)
		local atm = getClosestAtm(maxDistance)
		if not atm then
			return nil, 'Stand next to an outdoor ATM to use the hacking device.'
		end

		local atmCoords = atm.coords or GetEntityCoords(atm.entity)
		return {
			effectType = effectType,
			atm = atm.entity,
			coords = {
				x = tonumber(atmCoords.x) or 0.0,
				y = tonumber(atmCoords.y) or 0.0,
				z = tonumber(atmCoords.z) or 0.0
			},
			maxDistance = maxDistance
		}, nil
	end

	return nil, nil
end

local function getVehicleFromUseContext(effect, context)
	if type(context) ~= 'table' then
		return 0, nil
	end

	local vehicle = tonumber(context.vehicle) or 0
	if vehicle ~= 0 and DoesEntityExist(vehicle) then
		return vehicle, type(context.fuelData) == 'table' and context.fuelData or nil
	end

	local networkId = tonumber(context.networkId) or 0
	if networkId > 0 and NetworkDoesEntityExistWithNetworkId(networkId) then
		local networkVehicle = NetworkGetEntityFromNetworkId(networkId)
		if networkVehicle ~= 0 and DoesEntityExist(networkVehicle) then
			return networkVehicle, type(context.fuelData) == 'table' and context.fuelData or nil
		end
	end

	if type(effect) == 'table' then
		local effectType = tostring(effect.type or '')
		if effectType == 'vehicle_refuel_amount' or effectType == 'vehicle_refuel_full' then
			return getClosestRefuelableVehicle(math.max(1.0, tonumber(context.maxDistance) or tonumber(effect.maxDistance) or 4.0))
		elseif effectType == 'vehicle_repair_full' then
			return getClosestNearbyVehicle(math.max(1.0, tonumber(context.maxDistance) or tonumber(effect.maxDistance) or 4.0))
		end
	end

	return 0, nil
end

local function applyUseEffect(effect, context)
	if type(effect) ~= 'table' then
		return false
	end

	local ped = PlayerPedId()
	if ped == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) then
		return false
	end

	if tostring(effect.type or '') == 'heal' then
		local healAmount = math.max(1, math.floor(tonumber(effect.amount) or 1))
		local currentHealth = GetEntityHealth(ped)
		local maxHealth = GetEntityMaxHealth(ped)
		if currentHealth <= 0 or maxHealth <= 0 then
			return false
		end

		SetEntityHealth(ped, math.min(maxHealth, currentHealth + healAmount))
		return true
	end

	if tostring(effect.type or '') == 'vehicle_refuel_amount' then
		if GetResourceState('lsrp_fuel') ~= 'started' then
			notifyLocal('Fuel service is unavailable right now.')
			return false
		end

		local requestedAmount = math.max(0.1, tonumber(effect.amount) or 20.0)
		local closestVehicle, fuelData = getVehicleFromUseContext(effect, context)

		if closestVehicle == 0 then
			notifyLocal('Stand next to a vehicle to use the gas can.')
			return false
		end

		if type(fuelData) ~= 'table' then
			notifyLocal('That vehicle cannot be refueled right now.')
			return false
		end

		local fuelNeeded = math.max(0.0, fuelData.tankCapacity - fuelData.currentFuel)
		if fuelNeeded <= 0.25 then
			notifyLocal('That vehicle is already full.')
			return false
		end

		local amountToAdd = math.min(requestedAmount, fuelNeeded)
		requestVehicleControl(closestVehicle, 1000)
		local okAddFuel, resultFuel = pcall(function()
			return exports['lsrp_fuel']:addFuel(closestVehicle, amountToAdd)
		end)
		if not okAddFuel or type(resultFuel) ~= 'number' then
			notifyLocal('Fueling the nearby vehicle failed.')
			return false
		end

		local appliedAmount = math.max(0.0, math.floor((math.min(resultFuel, fuelData.tankCapacity) - fuelData.currentFuel) * 10.0 + 0.5) / 10.0)
		if appliedAmount <= 0.0 then
			notifyLocal('That vehicle is already full.')
			return false
		end

		notifyLocal(('Added %.1f liters to the nearby vehicle.'):format(appliedAmount))
		return true
	end

	if tostring(effect.type or '') == 'vehicle_refuel_full' then
		if GetResourceState('lsrp_fuel') ~= 'started' then
			notifyLocal('Fuel service is unavailable right now.')
			return false
		end

		local maxDistance = math.max(1.0, tonumber(effect.maxDistance) or 4.0)
        local closestVehicle, fuelData = getClosestRefuelableVehicle(maxDistance)

		if closestVehicle == 0 then
			notifyLocal('Stand next to a vehicle to use the gas can.')
			return false
		end

		if type(fuelData) ~= 'table' then
			notifyLocal('That vehicle cannot be refueled right now.')
			return false
		end

		if fuelData.currentFuel >= (fuelData.tankCapacity - 0.25) then
			notifyLocal('That vehicle is already full.')
			return false
		end

		local okSetFuel, resultFuel = pcall(function()
			return exports['lsrp_fuel']:setFuel(closestVehicle, fuelData.tankCapacity)
		end)
		if not okSetFuel or type(resultFuel) ~= 'number' then
			notifyLocal('Fueling the nearby vehicle failed.')
			return false
		end

		notifyLocal('Filled the nearby vehicle with your gas can.')
		return true
	end

	if tostring(effect.type or '') == 'vehicle_repair_full' then
		local closestVehicle = getVehicleFromUseContext(effect, context)
		if closestVehicle == 0 then
			notifyLocal('Stand next to a vehicle to use the repair kit.')
			return false
		end

		if not repairVehicleFully(closestVehicle) then
			notifyLocal('Repairing the nearby vehicle failed.')
			return false
		end

		notifyLocal('Repaired the nearby vehicle with your repair kit.')
		return true
	end

	if tostring(effect.type or '') == 'atm_hacking_animation' then
		if type(context) ~= 'table' or type(context.coords) ~= 'table' then
			return false
		end

		if GetResourceState('lsrp_hacking') == 'started' then
			local ok, success, errorMessage = pcall(function()
				return exports['lsrp_hacking']:startAtmHack({
					x = tonumber(context.coords.x) or 0.0,
					y = tonumber(context.coords.y) or 0.0,
					z = tonumber(context.coords.z) or 0.0,
					atm = tonumber(context.atm) or 0
				})
			end)
			if not ok or success ~= true then
				notifyLocal(tostring(errorMessage or 'The ATM hack failed.'))
				return false
			end
		else
			notifyLocal('Hacking service is unavailable right now.')
			return false
		end

		return true
	end

	return false
end

local function canApplyUseEffect(effect, context)
	if type(effect) ~= 'table' then
		return true
	end

	if tostring(effect.type or '') == 'vehicle_refuel_amount' then
		local ped = PlayerPedId()
		if ped == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) then
			return false, 'You cannot use that right now.'
		end

		if GetResourceState('lsrp_fuel') ~= 'started' then
			return false, 'Fuel service is unavailable right now.'
		end

		local vehicle, fuelData = getVehicleFromUseContext(effect, context)
		if vehicle ~= 0 and type(fuelData) == 'table' then
			if fuelData.currentFuel < (fuelData.tankCapacity - 0.25) then
				return true, nil
			end
			return false, 'That vehicle is already full.'
		end

		return false, 'Stand next to a vehicle to use the gas can.'
	end

	if tostring(effect.type or '') == 'vehicle_refuel_full' then
		local ped = PlayerPedId()
		if ped == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) then
			return false, 'You cannot use that right now.'
		end

		if GetResourceState('lsrp_fuel') ~= 'started' then
			return false, 'Fuel service is unavailable right now.'
		end

		local maxDistance = math.max(1.0, tonumber(effect.maxDistance) or 4.0)
		local vehicle, fuelData = getClosestRefuelableVehicle(maxDistance)
		if vehicle ~= 0 and type(fuelData) == 'table' then
			if fuelData.currentFuel < (fuelData.tankCapacity - 0.25) then
				return true, nil
			end
			return false, 'That vehicle is already full.'
		end

		return false, 'Stand next to a vehicle to use the gas can.'
	end

	if tostring(effect.type or '') == 'vehicle_repair_full' then
		local ped = PlayerPedId()
		if ped == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) then
			return false, 'You cannot use that right now.'
		end

		local vehicle = getVehicleFromUseContext(effect, context)
		if vehicle ~= 0 then
			return true, nil
		end

		return false, 'Stand next to a vehicle to use the repair kit.'
	end

	if tostring(effect.type or '') == 'atm_hacking_animation' then
		local ped = PlayerPedId()
		if ped == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) then
			return false, 'You cannot use that right now.'
		end

		local atm = getClosestAtm(math.max(0.5, tonumber(context and context.maxDistance) or tonumber(effect.maxDistance) or 1.8))
		if atm then
			return true, nil
		end

		return false, 'Stand next to an ATM to use the hacking device.'
	end

	if tostring(effect.type or '') == 'hunger' then
		if GetResourceState('lsrp_hunger') ~= 'started' then
			return false, 'Hunger service is unavailable right now.'
		end

		local maxHunger = 100
		local okMaxHunger, exportedMaxHunger = pcall(function()
			return exports['lsrp_hunger']:getMaxHunger()
		end)
		if okMaxHunger then
			maxHunger = math.max(1, math.floor(tonumber(exportedMaxHunger) or maxHunger))
		end

		local currentHunger = nil
		local okCurrentHunger, exportedCurrentHunger = pcall(function()
			return exports['lsrp_hunger']:getCurrentHunger()
		end)
		if okCurrentHunger then
			currentHunger = tonumber(exportedCurrentHunger)
		end

		if currentHunger and currentHunger >= maxHunger then
			return false, 'You are not hungry right now.'
		end

		return true, nil
	end

	return true, nil
end

local function buildNearbyPlayersPayload()
	local payload = {}
	local playerPed = PlayerPedId()
	if playerPed == 0 then
		return payload
	end

	local playerCoords = GetEntityCoords(playerPed)
	for _, playerId in ipairs(GetActivePlayers()) do
		if playerId ~= PlayerId() then
			local targetPed = GetPlayerPed(playerId)
			if targetPed ~= 0 then
				local targetCoords = GetEntityCoords(targetPed)
				local distance = #(playerCoords - targetCoords)
				if distance <= getTransferRange() then
					payload[#payload + 1] = {
						targetId = GetPlayerServerId(playerId),
						targetName = GetPlayerName(playerId) or ('ID ' .. tostring(GetPlayerServerId(playerId))),
						distance = math.floor((distance * 10.0) + 0.5) / 10.0
					}
				end
			end
		end
	end

	table.sort(payload, function(left, right)
		if left.distance == right.distance then
			return left.targetId < right.targetId
		end
		return left.distance < right.distance
	end)

	return payload
end

local function refreshNearbyPlayers()
	latestNearbyPlayers = buildNearbyPlayersPayload()
	if uiOpen then
		SendNUIMessage({ action = 'setNearbyPlayers', players = latestNearbyPlayers })
	end
	return latestNearbyPlayers
end

local function setUiOpen(shouldOpen)
	if uiOpen == shouldOpen then
		return
	end

	uiOpen = shouldOpen
	SetNuiFocus(shouldOpen, shouldOpen)
	SendNUIMessage({ action = 'setVisible', visible = shouldOpen })

	if shouldOpen then
		SendNUIMessage({ action = 'setInventoryData', inventory = latestInventory })
		SendNUIMessage({ action = 'setSecondaryTarget', target = getActiveTarget() })
		SendNUIMessage({ action = 'setNearbyPlayers', players = latestNearbyPlayers })
	else
		latestTransferTarget = nil
		latestStashTarget = nil
		SendNUIMessage({ action = 'clearSecondaryTarget' })
	end
end

local function requestOpenInventory()
	if useInProgress then
		notifyLocal('Finish using your current item first.')
		return
	end

	refreshNearbyPlayers()
	TriggerServerEvent('lsrp_inventory:server:requestOpen')
end

RegisterNetEvent('lsrp_inventory:client:receiveInventory', function(inventory)
	latestInventory = normalizeInventoryPayload(inventory)
	if uiOpen then
		SendNUIMessage({ action = 'setInventoryData', inventory = latestInventory })
	else
		setUiOpen(true)
	end
end)

RegisterNetEvent('lsrp_inventory:client:openInventoryWithStash', function(inventory, targetPayload)
	latestInventory = normalizeInventoryPayload(inventory)
	latestTransferTarget = nil
	latestStashTarget = type(targetPayload) == 'table' and targetPayload or nil
	setUiOpen(true)
end)

RegisterNetEvent('lsrp_inventory:client:syncInventory', function(inventory)
	latestInventory = normalizeInventoryPayload(inventory)
	if uiOpen then
		SendNUIMessage({ action = 'setInventoryData', inventory = latestInventory })
	end
end)

RegisterNetEvent('lsrp_inventory:client:syncTransferTarget', function(targetPayload)
	latestTransferTarget = type(targetPayload) == 'table' and targetPayload or nil
	if uiOpen then
		SendNUIMessage({ action = 'setSecondaryTarget', target = getActiveTarget() })
	end
end)

RegisterNetEvent('lsrp_inventory:client:syncStashTarget', function(targetPayload)
	latestStashTarget = type(targetPayload) == 'table' and targetPayload or nil
	if uiOpen then
		SendNUIMessage({ action = 'setSecondaryTarget', target = getActiveTarget() })
	end
end)

RegisterNetEvent('lsrp_inventory:client:setWorldDrops', function(drops)
	worldDrops = {}
	for _, drop in ipairs(type(drops) == 'table' and drops or {}) do
		worldDrops[tonumber(drop.id)] = drop
	end
end)

RegisterNetEvent('lsrp_inventory:client:addWorldDrop', function(drop)
	if type(drop) ~= 'table' or not drop.id then
		return
	end
	worldDrops[tonumber(drop.id)] = drop
end)

RegisterNetEvent('lsrp_inventory:client:removeWorldDrop', function(dropId)
	worldDrops[tonumber(dropId)] = nil
end)

RegisterNetEvent('lsrp_inventory:client:setNearbyPlayers', function(players)
	latestNearbyPlayers = type(players) == 'table' and players or {}
	if uiOpen then
		SendNUIMessage({ action = 'setNearbyPlayers', players = latestNearbyPlayers })
	end
end)

RegisterNUICallback('closeInventory', function(_, cb)
	TriggerServerEvent('lsrp_inventory:server:clearTargetContext')
	setUiOpen(false)
	cb({ ok = true })
end)

RegisterNUICallback('closeTargetContext', function(_, cb)
	TriggerServerEvent('lsrp_inventory:server:clearTargetContext')
	cb({ ok = true })
end)

RegisterNUICallback('requestInventory', function(_, cb)
	requestOpenInventory()
	cb({ ok = true })
end)

RegisterNUICallback('requestTransferTargetInventory', function(data, cb)
	local targetId = math.floor(tonumber(data and data.targetId) or 0)
	if targetId < 1 then
		cb({ ok = false, error = 'invalid_target' })
		return
	end
	TriggerServerEvent('lsrp_inventory:server:requestTransferTargetInventory', targetId)
	cb({ ok = true })
end)

RegisterNUICallback('requestNearbyPlayers', function(_, cb)
	refreshNearbyPlayers()
	cb({ ok = true })
end)

RegisterNUICallback('moveItem', function(data, cb)
	local fromSlot = math.floor(tonumber(data and data.fromSlot) or 0)
	local toSlot = math.floor(tonumber(data and data.toSlot) or 0)
	local amount = math.floor(tonumber(data and data.amount) or 1)
	if fromSlot < 1 or toSlot < 1 then
		cb({ ok = false, error = 'invalid_slots' })
		return
	end
	TriggerServerEvent('lsrp_inventory:server:moveItem', fromSlot, toSlot, amount)
	cb({ ok = true })
end)

RegisterNUICallback('giveItem', function(data, cb)
	local targetId = math.floor(tonumber(data and data.targetId) or 0)
	local fromSlot = math.floor(tonumber(data and data.fromSlot) or 0)
	local toSlot = math.floor(tonumber(data and data.toSlot) or 0)
	local amount = math.floor(tonumber(data and data.amount) or 1)
	if targetId < 1 or fromSlot < 1 then
		cb({ ok = false, error = 'invalid_params' })
		return
	end
	TriggerServerEvent('lsrp_inventory:server:giveItem', targetId, fromSlot, toSlot, amount)
	cb({ ok = true })
end)

RegisterNUICallback('storeItemInStash', function(data, cb)
	local stashId = tostring(data and data.stashId or '')
	local fromSlot = math.floor(tonumber(data and data.fromSlot) or 0)
	local toSlot = math.floor(tonumber(data and data.toSlot) or 0)
	local amount = math.floor(tonumber(data and data.amount) or 1)
	if stashId == '' or fromSlot < 1 then
		cb({ ok = false, error = 'invalid_params' })
		return
	end
	TriggerServerEvent('lsrp_inventory:server:storeItemInStash', stashId, fromSlot, toSlot, amount)
	cb({ ok = true })
end)

RegisterNUICallback('takeItemFromStash', function(data, cb)
	local stashId = tostring(data and data.stashId or '')
	local fromSlot = math.floor(tonumber(data and data.fromSlot) or 0)
	local toSlot = math.floor(tonumber(data and data.toSlot) or 0)
	local amount = math.floor(tonumber(data and data.amount) or 1)
	if stashId == '' or fromSlot < 1 or toSlot < 1 then
		cb({ ok = false, error = 'invalid_params' })
		return
	end
	TriggerServerEvent('lsrp_inventory:server:takeItemFromStash', stashId, fromSlot, toSlot, amount)
	cb({ ok = true })
end)

RegisterNUICallback('moveItemInStash', function(data, cb)
	local stashId = tostring(data and data.stashId or '')
	local fromSlot = math.floor(tonumber(data and data.fromSlot) or 0)
	local toSlot = math.floor(tonumber(data and data.toSlot) or 0)
	local amount = math.floor(tonumber(data and data.amount) or 1)
	if stashId == '' or fromSlot < 1 or toSlot < 1 then
		cb({ ok = false, error = 'invalid_params' })
		return
	end
	TriggerServerEvent('lsrp_inventory:server:moveItemInStash', stashId, fromSlot, toSlot, amount)
	cb({ ok = true })
end)

RegisterNUICallback('dropItem', function(data, cb)
	local fromSlot = math.floor(tonumber(data and data.fromSlot) or 0)
	local amount = math.floor(tonumber(data and data.amount) or 1)
	if fromSlot < 1 then
		cb({ ok = false, error = 'invalid_slot' })
		return
	end
	TriggerServerEvent('lsrp_inventory:server:dropItem', fromSlot, amount)
	cb({ ok = true })
end)

RegisterNUICallback('trashItem', function(data, cb)
	local fromSlot = math.floor(tonumber(data and data.fromSlot) or 0)
	local amount = math.floor(tonumber(data and data.amount) or 1)
	if fromSlot < 1 then
		cb({ ok = false, error = 'invalid_slot' })
		return
	end
	TriggerServerEvent('lsrp_inventory:server:trashItem', fromSlot, amount)
	cb({ ok = true })
end)

RegisterNUICallback('useItem', function(data, cb)
	if useInProgress then
		cb({ ok = false, error = 'busy' })
		return
	end

	local fromSlot = math.floor(tonumber(data and data.fromSlot) or 0)
	if fromSlot < 1 then
		cb({ ok = false, error = 'invalid_slot' })
		return
	end

	local item = getInventoryItemBySlot(fromSlot)
	if not item then
		cb({ ok = false, error = 'item_not_found' })
		return
	end

	if type(item.use) ~= 'table' then
		cb({ ok = false, error = 'not_usable' })
		return
	end

	TriggerServerEvent('lsrp_inventory:server:useItem', fromSlot)
	cb({ ok = true })
end)

RegisterNetEvent('lsrp_inventory:client:startUseItem', function(payload)
	payload = type(payload) == 'table' and payload or {}
	local token = tostring(payload.token or '')
	local useData = type(payload.use) == 'table' and payload.use or nil
	local item = type(payload.item) == 'table' and payload.item or {}
	local durationMs = math.max(1000, math.floor(tonumber(useData and useData.durationMs) or 10000))
	local itemLabel = tostring(item.label or item.name or 'item')

	if token == '' or not useData then
		activeUseContext = nil
		TriggerServerEvent('lsrp_inventory:server:cancelUseItem', token)
		return
	end

	if useInProgress then
		activeUseContext = nil
		TriggerServerEvent('lsrp_inventory:server:cancelUseItem', token)
		notifyLocal('You are already using an item.')
		return
	end

	setUiOpen(false)
	useInProgress = true
	activeUseToken = token
	activeUseContext = nil

	local effectContext, effectContextError = buildUseEffectContext(useData.effect)
	if effectContextError then
		finishUseAnimation()
		TriggerServerEvent('lsrp_inventory:server:cancelUseItem', token)
		notifyLocal(effectContextError)
		return
	end
	activeUseContext = effectContext

	CreateThread(function()
		local started, errorCode = playItemUseAnimation(useData)
		if not started then
			finishUseAnimation()
			activeUseContext = nil
			TriggerServerEvent('lsrp_inventory:server:cancelUseItem', token)
			if errorCode == 'in_vehicle' then
				notifyLocal('Exit your vehicle before using that item.')
			else
				notifyLocal(('Could not use %s right now.'):format(itemLabel))
			end
			return
		end

		local deadline = GetGameTimer() + durationMs
		local cancelled = false
		while GetGameTimer() < deadline do
			Citizen.Wait(0)
			DisableControlAction(0, 24, true)
			DisableControlAction(0, 25, true)
			DisableControlAction(0, 37, true)
			DisableControlAction(0, 44, true)
			DisableControlAction(0, 140, true)
			DisableControlAction(0, 141, true)
			DisableControlAction(0, 142, true)
			DisableControlAction(0, 21, true)
			DisableControlAction(0, 22, true)
			if IsEntityDead(PlayerPedId()) or IsPedRagdoll(PlayerPedId()) then
				cancelled = true
				break
			end
		end

		finishUseAnimation()
		if cancelled then
			activeUseContext = nil
			TriggerServerEvent('lsrp_inventory:server:cancelUseItem', token)
			notifyLocal(('Using %s was interrupted.'):format(itemLabel))
			return
		end

		local effectAllowed, effectError = canApplyUseEffect(useData.effect, activeUseContext)
		if effectAllowed ~= true then
			activeUseContext = nil
			TriggerServerEvent('lsrp_inventory:server:cancelUseItem', token)
			notifyLocal(effectError or ('Could not use %s right now.'):format(itemLabel))
			return
		end

		TriggerServerEvent('lsrp_inventory:server:completeUseItem', token)
	end)
end)

RegisterNetEvent('lsrp_inventory:client:applyUseEffect', function(effect)
	applyUseEffect(effect, activeUseContext)
	activeUseContext = nil
end)

RegisterCommand('inventory', function()
	if uiOpen then
		setUiOpen(false)
	else
		requestOpenInventory()
	end
end, false)

RegisterCommand('+openInventory', function()
	if uiOpen then
		setUiOpen(false)
	else
		requestOpenInventory()
	end
end, false)

RegisterCommand('-openInventory', function()
	-- Required for RegisterKeyMapping.
end, false)

RegisterKeyMapping('+openInventory', 'Open inventory', 'keyboard', 'I')

Citizen.CreateThread(function()
	while true do
		if uiOpen then
			refreshNearbyPlayers()
			Citizen.Wait(750)
		else
			Citizen.Wait(250)
		end
	end
end)

Citizen.CreateThread(function()
	TriggerServerEvent('lsrp_inventory:server:requestWorldDrops')
	while true do
		Citizen.Wait(0)
		local ped = PlayerPedId()
		local coords = GetEntityCoords(ped)
		for dropId, drop in pairs(worldDrops) do
			local position = drop.position or {}
			local dropCoords = vector3(position.x or 0.0, position.y or 0.0, position.z or 0.0)
			local distance = #(coords - dropCoords)
			if distance < 35.0 then
				DrawMarker(2, dropCoords.x, dropCoords.y, dropCoords.z + 0.15, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.18, 0.18, 0.18, 233, 196, 106, 180, false, false, 2, true, nil, nil, false)
			end
			if distance < 1.6 then
				SetTextComponentFormat('STRING')
				AddTextComponentString(('Press ~INPUT_CONTEXT~ to pick up %s x%d'):format(tostring((drop.item and (drop.item.label or drop.item.name)) or 'Item'), math.floor(tonumber(drop.item and drop.item.count) or 1)))
				DisplayHelpTextFromStringLabel(0, 0, 1, -1)
				if IsControlJustReleased(0, 38) then
					TriggerServerEvent('lsrp_inventory:server:pickupWorldDrop', dropId)
				end
			end
		end
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end
	finishUseAnimation()
	SetNuiFocus(false, false)
end)

print('[lsrp_inventory] Rebuilt client loaded')
