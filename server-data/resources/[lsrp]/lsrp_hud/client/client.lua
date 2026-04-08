local COMPASS_HUD_FALLBACK_UPDATE_MS = 100
local NEEDS_HUD_FALLBACK_UPDATE_MS = 500
local VEHICLE_SPEED_TO_KMH = 3.6
local DEFAULT_MAX_HUNGER = 100
local DEFAULT_MAX_THIRST = 100
local DEFAULT_MAX_FUEL_PERCENT = 100

local DIRECTION_LABELS = {
	[0] = 'N',
	[45] = 'NE',
	[90] = 'E',
	[135] = 'SE',
	[180] = 'S',
	[225] = 'SW',
	[270] = 'W',
	[315] = 'NW'
}

local compassVisible = false
local lastPayloadKey = nil
local needsVisible = false
local lastNeedsPayloadKey = nil
local lastLayoutPayloadKey = nil
local cachedHungerValue = nil
local cachedThirstValue = nil
local directHungerPercent = nil
local directThirstPercent = nil
local treatmentVisible = false
local lastTreatmentPayloadKey = nil

local function getHudWidgetLayoutConfig()
	local widgetConfig = lsrpConfig and lsrpConfig.hudWidgets or {}
	local needsShellConfig = type(widgetConfig.needsShell) == 'table' and widgetConfig.needsShell or {}
	local fuelShellConfig = type(widgetConfig.fuelShell) == 'table' and widgetConfig.fuelShell or {}

	return {
		needsShell = {
			left = tostring(needsShellConfig.left or '26.125rem'),
			bottom = tostring(needsShellConfig.bottom or '0.95rem'),
			width = tostring(needsShellConfig.width or 'min(16rem, 24vw)'),
			transform = tostring(needsShellConfig.transform or 'none'),
			mobileLeft = tostring(needsShellConfig.mobileLeft or '1rem'),
			mobileRight = tostring(needsShellConfig.mobileRight or 'auto'),
			mobileBottom = tostring(needsShellConfig.mobileBottom or '5.75rem'),
			mobileWidth = tostring(needsShellConfig.mobileWidth or 'min(16rem, calc(100vw - 2rem))'),
			mobileTransform = tostring(needsShellConfig.mobileTransform or 'none')
		},
		fuelShell = {
			left = tostring(fuelShellConfig.left or '50%'),
			bottom = tostring(fuelShellConfig.bottom or '1rem'),
			width = tostring(fuelShellConfig.width or 'min(16rem, calc(100vw - 2rem))'),
			transform = tostring(fuelShellConfig.transform or 'translateX(-50%)'),
			mobileLeft = tostring(fuelShellConfig.mobileLeft or '50%'),
			mobileRight = tostring(fuelShellConfig.mobileRight or 'auto'),
			mobileBottom = tostring(fuelShellConfig.mobileBottom or '1rem'),
			mobileWidth = tostring(fuelShellConfig.mobileWidth or 'min(16rem, calc(100vw - 2rem))'),
			mobileTransform = tostring(fuelShellConfig.mobileTransform or 'translateX(-50%)')
		}
	}
end

local function pushHudWidgetLayoutConfig()
	local payload = getHudWidgetLayoutConfig()
	local payloadKey = table.concat({
		payload.needsShell.left,
		payload.needsShell.bottom,
		payload.needsShell.width,
		payload.needsShell.transform,
		payload.needsShell.mobileLeft,
		payload.needsShell.mobileRight,
		payload.needsShell.mobileBottom,
		payload.needsShell.mobileWidth,
		payload.needsShell.mobileTransform,
		payload.fuelShell.left,
		payload.fuelShell.bottom,
		payload.fuelShell.width,
		payload.fuelShell.transform,
		payload.fuelShell.mobileLeft,
		payload.fuelShell.mobileRight,
		payload.fuelShell.mobileBottom,
		payload.fuelShell.mobileWidth,
		payload.fuelShell.mobileTransform
	}, '|')

	if payloadKey == lastLayoutPayloadKey then
		return
	end

	lastLayoutPayloadKey = payloadKey
	SendNUIMessage({
		action = 'hudLayout:update',
		data = payload
	})
end

local function isCompassEnabled()
	if not lsrpConfig then
		return true
	end

	return lsrpConfig.compassEnabled ~= false
end

local function shouldUseCameraHeading()
	if not lsrpConfig then
		return true
	end

	return lsrpConfig.compassUseCameraHeading ~= false
end

local function shouldShowDegrees()
	if not lsrpConfig then
		return true
	end

	return lsrpConfig.compassShowDegrees ~= false
end

local function shouldShowDirectionText()
	if not lsrpConfig then
		return true
	end

	return lsrpConfig.compassShowDirectionText ~= false
end

local function isCoordinateHudEnabled()
	if not lsrpConfig then
		return true
	end

	return lsrpConfig.coordinateHudEnabled ~= false
end

local function shouldShowCoordinateHeading()
	if not lsrpConfig then
		return true
	end

	return lsrpConfig.coordinateHudShowHeading ~= false
end

local function shouldShowCoordinateStreet()
	if not lsrpConfig then
		return true
	end

	return lsrpConfig.coordinateHudShowStreet ~= false
end

local function getCompassHudUpdateInterval()
	if not lsrpConfig then
		return COMPASS_HUD_FALLBACK_UPDATE_MS
	end

	local configuredInterval = tonumber(lsrpConfig.coordinateHudUpdateIntervalMs)
	if configuredInterval and configuredInterval >= 50 then
		return math.floor(configuredInterval)
	end

	return COMPASS_HUD_FALLBACK_UPDATE_MS
end

local function isHungerHudEnabled()
	if not lsrpConfig then
		return true
	end

	return lsrpConfig.hungerHudEnabled ~= false
end

local function getNeedsHudUpdateInterval()
	if not lsrpConfig then
		return NEEDS_HUD_FALLBACK_UPDATE_MS
	end

	local configuredInterval = tonumber(lsrpConfig.hungerHudUpdateIntervalMs)
	if configuredInterval and configuredInterval >= 100 then
		return math.floor(configuredInterval)
	end

	return NEEDS_HUD_FALLBACK_UPDATE_MS
end

local function clampNumber(value, minimum, maximum)
	value = tonumber(value)
	if not value then
		return minimum
	end

	if value < minimum then
		return minimum
	end

	if value > maximum then
		return maximum
	end

	return value
end

local function isHungerResourceStarted()
	return GetResourceState('lsrp_hunger') == 'started'
end

local function getMaxHungerValue()
	if not isHungerResourceStarted() then
		return DEFAULT_MAX_HUNGER
	end

	local ok, value = pcall(function()
		return exports['lsrp_hunger']:getMaxHunger()
	end)

	if not ok then
		return DEFAULT_MAX_HUNGER
	end

	value = tonumber(value)
	if not value or value <= 0 then
		return DEFAULT_MAX_HUNGER
	end

	return math.floor(value)
end

local function getCurrentHungerValue()
	if cachedHungerValue ~= nil then
		return tonumber(cachedHungerValue)
	end

	if not isHungerResourceStarted() then
		return nil
	end

	local localState = LocalPlayer and LocalPlayer.state
	if localState and localState.lsrp_hunger ~= nil then
		return tonumber(localState.lsrp_hunger)
	end

	local ok, value = pcall(function()
		return exports['lsrp_hunger']:getCurrentHunger()
	end)

	if not ok then
		return nil
	end

	return tonumber(value)
end

local function getCurrentThirstValue()
	if cachedThirstValue ~= nil then
		return tonumber(cachedThirstValue)
	end

	if GetResourceState('lsrp_thirst') ~= 'started' then
		return nil
	end

	local localState = LocalPlayer and LocalPlayer.state
	if localState then
		if localState.lsrp_thirst ~= nil then
			return tonumber(localState.lsrp_thirst)
		end

		if localState.thirst ~= nil then
			return tonumber(localState.thirst)
		end
	end

	local ok, value = pcall(function()
		return exports['lsrp_thirst']:getCurrentThirst()
	end)

	if not ok then
		return nil
	end

	return tonumber(value)
end

local function getMaxThirstValue()
	if GetResourceState('lsrp_thirst') ~= 'started' then
		return DEFAULT_MAX_THIRST
	end

	local ok, value = pcall(function()
		return exports['lsrp_thirst']:getMaxThirst()
	end)

	if not ok then
		return DEFAULT_MAX_THIRST
	end

	value = tonumber(value)
	if not value or value <= 0 then
		return DEFAULT_MAX_THIRST
	end

	return math.floor(value)
end

local function getHungerPercent()
	local currentHunger = getCurrentHungerValue()
	if currentHunger == nil then
		return nil
	end

	local maxHunger = getMaxHungerValue()
	if maxHunger <= 0 then
		maxHunger = DEFAULT_MAX_HUNGER
	end

	currentHunger = clampNumber(currentHunger, 0, maxHunger)
	return math.floor(((currentHunger / maxHunger) * 100.0) + 0.5)
end

local function getThirstPercent()
	local currentThirst = getCurrentThirstValue()
	if currentThirst == nil then
		return nil
	end

	local maxThirst = getMaxThirstValue()
	currentThirst = clampNumber(currentThirst, 0, maxThirst)
	return math.floor(((currentThirst / maxThirst) * 100.0) + 0.5)
end

local function getVehicleFuelSnapshot(vehicle)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return nil, nil
	end

	local entityState = Entity(vehicle).state
	if not entityState then
		return nil, nil
	end

	local fuelLevel = tonumber(entityState.lsrpFuelLevel)
	local tankCapacity = tonumber(entityState.lsrpFuelCapacity)
	if fuelLevel == nil or tankCapacity == nil or tankCapacity <= 0 then
		return nil, nil
	end

	return fuelLevel, tankCapacity
end

local function getFuelPercent()
	local ped = PlayerPedId()
	if ped == 0 or not DoesEntityExist(ped) or not IsPedInAnyVehicle(ped, false) then
		return nil
	end

	local vehicle = GetVehiclePedIsIn(ped, false)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return nil
	end

	local fuelLevel, tankCapacity = getVehicleFuelSnapshot(vehicle)
	if fuelLevel ~= nil and tankCapacity ~= nil then
		fuelLevel = clampNumber(fuelLevel, 0, tankCapacity)
		return math.floor(((fuelLevel / tankCapacity) * DEFAULT_MAX_FUEL_PERCENT) + 0.5)
	end

	if GetResourceState('lsrp_fuel') ~= 'started' then
		return nil
	end

	local okFuel, exportedFuelLevel = pcall(function()
		return exports['lsrp_fuel']:getFuel(vehicle)
	end)

	if not okFuel or type(exportedFuelLevel) ~= 'number' then
		return nil
	end

	local okCapacity, exportedTankCapacity = pcall(function()
		return exports['lsrp_fuel']:getTankCapacity(vehicle)
	end)

	if not okCapacity or type(exportedTankCapacity) ~= 'number' or exportedTankCapacity <= 0 then
		return nil
	end

	fuelLevel = clampNumber(exportedFuelLevel, 0, exportedTankCapacity)
	tankCapacity = exportedTankCapacity
	return math.floor(((fuelLevel / tankCapacity) * DEFAULT_MAX_FUEL_PERCENT) + 0.5)
end

local function normalizeHeading(heading)
	local normalized = tonumber(heading) or 0.0
	normalized = normalized % 360.0
	if normalized < 0.0 then
		normalized = normalized + 360.0
	end

	return normalized
end

local function getCompassHeading()
	if shouldUseCameraHeading() then
		local camRotation = GetGameplayCamRot(2)
		if camRotation then
			return normalizeHeading(360.0 - (tonumber(camRotation.z) or 0.0))
		end
	end

	local ped = PlayerPedId()
	if ped ~= 0 and DoesEntityExist(ped) then
		return normalizeHeading(GetEntityHeading(ped))
	end

	return 0.0
end

local function getDirectionLabelForHeading(heading)
	local snapped = (math.floor((normalizeHeading(heading) + 22.5) / 45.0) * 45) % 360
	return DIRECTION_LABELS[snapped] or 'N'
end

local function getCoordinateStreetLabel(coords)
	if not shouldShowCoordinateStreet() then
		return nil
	end

	local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
	local primaryStreet = streetHash and streetHash ~= 0 and GetStreetNameFromHashKey(streetHash) or ''
	local crossingStreet = crossingHash and crossingHash ~= 0 and GetStreetNameFromHashKey(crossingHash) or ''

	if primaryStreet ~= '' and crossingStreet ~= '' then
		return ('%s / %s'):format(primaryStreet, crossingStreet)
	end

	if primaryStreet ~= '' then
		return primaryStreet
	end

	if crossingStreet ~= '' then
		return crossingStreet
	end

	return nil
end

local function getAreaLabel(coords)
	local zoneCode = GetNameOfZone(coords.x, coords.y, coords.z)
	if not zoneCode or zoneCode == '' then
		return 'San Andreas'
	end

	local zoneLabel = GetLabelText(zoneCode)
	if zoneLabel and zoneLabel ~= '' and zoneLabel ~= 'NULL' then
		return zoneLabel
	end

	return zoneCode
end

local function getVehicleDisplayName(vehicle)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return 'Vehicle'
	end

	local modelName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
	if not modelName or modelName == '' then
		return 'Vehicle'
	end

	local label = GetLabelText(modelName)
	if label and label ~= '' and label ~= 'NULL' then
		return label
	end

	return modelName
end

RegisterNetEvent('lsrp_hunger:client:update', function(hunger)
	cachedHungerValue = tonumber(hunger)
end)

RegisterNetEvent('lsrp_thirst:client:update', function(thirst)
	cachedThirstValue = tonumber(thirst)
end)

AddEventHandler('playerSpawned', function()
	cachedHungerValue = nil
	cachedThirstValue = nil
	lastNeedsPayloadKey = nil
	pushHudWidgetLayoutConfig()
end)

local function buildCompassPayload()
	if not isCompassEnabled() then
		return nil
	end

	local ped = PlayerPedId()
	if ped == 0 or not DoesEntityExist(ped) then
		return nil
	end

	local vehicle = GetVehiclePedIsIn(ped, false)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return nil
	end

	local coords = GetEntityCoords(ped)
	local compassHeading = normalizeHeading(getCompassHeading())
	local payload = {
		visible = true,
		heading = compassHeading,
		speed = math.max(0, math.floor((GetEntitySpeed(vehicle) * VEHICLE_SPEED_TO_KMH) + 0.5)),
		street = getCoordinateStreetLabel(coords),
		area = getAreaLabel(coords),
		vehicleName = getVehicleDisplayName(vehicle)
	}

	if payload.street == nil or payload.street == '' then
		payload.street = 'Unknown Road'
	end

	if not shouldShowCoordinateStreet() then
		payload.area = ''
	elseif payload.area == nil then
		payload.area = 'San Andreas'
	end

 	return payload
end

local function setCompassVisible(visible, payload)
	if visible == compassVisible and not payload then
		return
	end

	compassVisible = visible
	if visible then
		SendNUIMessage({
			action = 'vehicleCompass:show',
			data = payload or {}
		})
	else
		SendNUIMessage({
			action = 'vehicleCompass:hide'
		})
		lastPayloadKey = nil
	end
end

local function setNeedsVisible(visible, payload)
	if visible == needsVisible and not payload then
		return
	end

	needsVisible = visible
	if visible then
		SendNUIMessage({
			action = 'playerNeeds:show',
			data = payload or {}
		})
	else
		SendNUIMessage({
			action = 'playerNeeds:hide'
		})
		lastNeedsPayloadKey = nil
	end
end

local function setTreatmentVisible(visible, payload)
	if visible == treatmentVisible and not payload then
		return
	end

	treatmentVisible = visible
	if visible then
		SendNUIMessage({
			action = 'emsTreatment:show',
			data = payload or {}
		})
	else
		SendNUIMessage({
			action = 'emsTreatment:hide'
		})
		lastTreatmentPayloadKey = nil
	end
end

local function pushNeedsPayload()
	if IsPauseMenuActive() or not isHungerHudEnabled() then
		if needsVisible then
			setNeedsVisible(false)
		end
		return
	end

	local hungerPercent = directHungerPercent
	if hungerPercent == nil then
		hungerPercent = getHungerPercent()
	end

	local thirstPercent = directThirstPercent
	if thirstPercent == nil then
		thirstPercent = getThirstPercent()
	end

	local ped = PlayerPedId()
	local vehicle = 0
	local isDriverInVehicle = false
	if ped ~= 0 and DoesEntityExist(ped) and IsPedInAnyVehicle(ped, false) then
		vehicle = GetVehiclePedIsIn(ped, false)
		isDriverInVehicle = vehicle ~= 0 and DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle, -1) == ped
	end
	local fuelPercent = getFuelPercent()

	if hungerPercent == nil and thirstPercent == nil and fuelPercent == nil then
		if needsVisible then
			setNeedsVisible(false)
		end
		return
	end

	local payload = {
		visible = true,
		isDriverInVehicle = isDriverInVehicle == true,
		hunger = hungerPercent ~= nil and clampNumber(hungerPercent, 0, 100) or nil,
		thirst = thirstPercent ~= nil and clampNumber(thirstPercent, 0, 100) or nil,
		fuel = fuelPercent ~= nil and clampNumber(fuelPercent, 0, 100) or nil
	}

	local payloadKey = table.concat({
		payload.isDriverInVehicle and '1' or '0',
		tostring(payload.hunger or 'nil'),
		tostring(payload.thirst or 'nil'),
		tostring(payload.fuel or 'nil')
	}, '|')

	if not needsVisible then
		setNeedsVisible(true, payload)
		lastNeedsPayloadKey = payloadKey
		return
	end

	if payloadKey ~= lastNeedsPayloadKey then
		lastNeedsPayloadKey = payloadKey
		SendNUIMessage({
			action = 'playerNeeds:update',
			data = payload
		})
	end
end

RegisterNetEvent('lsrp_hud:client:setNeedPercent', function(needType, percent)
	local normalizedType = tostring(needType or '')
	local normalizedPercent = clampNumber(math.floor(tonumber(percent) or 0), 0, 100)

	if normalizedType == 'hunger' then
		directHungerPercent = normalizedPercent
	elseif normalizedType == 'thirst' then
		directThirstPercent = normalizedPercent
	else
		return
	end

	pushNeedsPayload()
end)

RegisterNetEvent('lsrp_hud:client:needUpdated', function(needType, value)
	local normalizedType = tostring(needType or '')
	if normalizedType == 'hunger' then
		cachedHungerValue = tonumber(value)
		directHungerPercent = nil
	elseif normalizedType == 'thirst' then
		cachedThirstValue = tonumber(value)
		directThirstPercent = nil
	else
		return
	end

	pushNeedsPayload()
end)

RegisterNetEvent('lsrp_hud:client:setTreatmentCountdown', function(payload)
	payload = type(payload) == 'table' and payload or nil
	if not payload or payload.visible ~= true then
		if treatmentVisible then
			setTreatmentVisible(false)
		end
		return
	end

	local remainingMs = math.max(0, math.floor(tonumber(payload.remainingMs) or 0))
	local percent = clampNumber(math.floor(tonumber(payload.percent) or 0), 0, 100)
	local label = tostring(payload.label or 'Treatment')
	local normalizedPayload = {
		visible = true,
		label = label,
		remainingMs = remainingMs,
		percent = percent
	}
	local payloadKey = table.concat({ label, tostring(remainingMs), tostring(percent) }, '|')

	if not treatmentVisible then
		setTreatmentVisible(true, normalizedPayload)
		lastTreatmentPayloadKey = payloadKey
		return
	end

	if payloadKey ~= lastTreatmentPayloadKey then
		lastTreatmentPayloadKey = payloadKey
		SendNUIMessage({
			action = 'emsTreatment:update',
			data = normalizedPayload
		})
	end
end)

CreateThread(function()
	pushHudWidgetLayoutConfig()

	while true do
		local payload = buildCompassPayload()
		if IsPauseMenuActive() or payload == nil then
			if compassVisible then
				setCompassVisible(false)
			end
			Wait(250)
		else
			HideHudComponentThisFrame(6)

			local payloadKey = table.concat({
				('%.3f'):format(payload.heading or 0.0),
				tostring(payload.speed or 0),
				payload.street or '',
				payload.area or '',
				payload.vehicleName or ''
			}, '|')

			if not compassVisible then
				setCompassVisible(true, payload)
				lastPayloadKey = payloadKey
			elseif payloadKey ~= lastPayloadKey then
				lastPayloadKey = payloadKey
				SendNUIMessage({
					action = 'vehicleCompass:update',
					data = payload
				})
			end

			Wait(getCompassHudUpdateInterval())
		end
	end
end)

CreateThread(function()
	while true do
		if IsPauseMenuActive() or not isHungerHudEnabled() then
			if needsVisible then
				setNeedsVisible(false)
			end

			Wait(250)
		else
			pushNeedsPayload()
			Wait(getNeedsHudUpdateInterval())
		end
	end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	SendNUIMessage({
		action = 'vehicleCompass:hide'
	})

	SendNUIMessage({
		action = 'playerNeeds:hide'
	})

	SendNUIMessage({
		action = 'emsTreatment:hide'
	})
end)