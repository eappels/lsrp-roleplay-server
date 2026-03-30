local COMPASS_HUD_FALLBACK_UPDATE_MS = 100
local VEHICLE_SPEED_TO_MPH = 2.236936

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
		speed = math.max(0, math.floor((GetEntitySpeed(vehicle) * VEHICLE_SPEED_TO_MPH) + 0.5)),
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

CreateThread(function()
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

AddEventHandler('onClientResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	SendNUIMessage({
		action = 'vehicleCompass:hide'
	})
end)