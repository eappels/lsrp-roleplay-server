-- LSRP Vehicle Editor - Client Script
--
-- Full in-vehicle modification editor: performance mods, visual mods, toggle
-- mods (turbo/xenon/tyre smoke), colors, neon, wheel type, window tint, and
-- liveries.  Setups (entire vehicle state snapshots) are saved in up to the
-- configured number of named slots server-side.
--
-- Player must be in the driver seat to open the editor.
-- Vehicle is repaired fully when the editor opens to ensure a clean baseline.
--
-- Commands / key bindings:
--   /vehicleeditor  or  /veditor  - toggle editor
--
-- Net events received:
--   lsrp_vehicleeditor:open   - open remotely
--   lsrp_vehicleeditor:close  - close remotely
--   lsrp_vehicleeditor:toggle - toggle remotely
--
-- Server communication uses the framework callback path.
-- Actions: listSetups, getSetup, saveSetup, deleteSetup

local MOD_TYPES = {
	0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
	11, 12, 13, 15, 16, 23, 24, 48
}

local TOGGLE_MOD_TYPES = { 18, 20, 22 }
local MIN_SLOT = 1
local MAX_SLOT = 10

local NEON_SIDE_TO_NATIVE_INDEX = {
	left = 2,
	right = 1,
	front = 3,
	back = 0
}

local NEON_SIDE_TO_LEGACY_INDEX = {
	left = 0,
	right = 1,
	front = 2,
	back = 3
}

local ALLOWED_MOD_LOOKUP = {}
for _, modType in ipairs(MOD_TYPES) do
	ALLOWED_MOD_LOOKUP[modType] = true
end

local TOGGLE_MOD_LOOKUP = {}
for _, modType in ipairs(TOGGLE_MOD_TYPES) do
	TOGGLE_MOD_LOOKUP[modType] = true
end

local MOD_LABELS = {
	[0] = 'Spoilers',
	[1] = 'Front Bumper',
	[2] = 'Rear Bumper',
	[3] = 'Side Skirt',
	[4] = 'Exhaust',
	[5] = 'Frame',
	[6] = 'Grille',
	[7] = 'Hood',
	[8] = 'Left Fender',
	[9] = 'Right Fender',
	[10] = 'Roof',
	[11] = 'Engine',
	[12] = 'Brakes',
	[13] = 'Transmission',
	[15] = 'Suspension',
	[16] = 'Armor',
	[23] = 'Front Wheels',
	[24] = 'Rear Wheels',
	[48] = 'Livery',
	[18] = 'Turbo',
	[20] = 'Tyre Smoke',
	[22] = 'Xenon'
}

local isEditorOpen = false
local initialSetup = nil
local previewCam = nil

local CAMERA_ROTATE_STEP = 1.8
local CAMERA_HEIGHT_STEP = 0.03
local CAMERA_DISTANCE_STEP = 0.08
local CAMERA_MIN_HEIGHT = -0.25
local CAMERA_MAX_HEIGHT = 3.5
local CAMERA_DISTANCE_OFFSET = 2.0

local cameraState = {
	w = false,
	s = false,
	a = false,
	d = false,
	q = false,
	e = false,
	angle = 180.0,
	height = 1.0,
	distance = 7.0
}

local pendingDeletion = nil

-- ---------------------------------------------------------------------------
-- Utility helpers
-- ---------------------------------------------------------------------------

local function toInteger(value, fallback)
	local number = tonumber(value)
	if not number then
		return fallback
	end

	return math.floor(number)
end

local function clamp(number, minValue, maxValue)
	if number < minValue then
		return minValue
	end

	if number > maxValue then
		return maxValue
	end

	return number
end

local function toBoolean(value)
	if value == true or value == 1 then
		return true
	end

	if type(value) == 'string' then
		local lowered = string.lower(value)
		return lowered == 'true' or lowered == '1'
	end

	return false
end

-- ---------------------------------------------------------------------------
-- Neon / color normalization helpers
-- (GTA uses 0-based neon indices natively, but older saved data may use 1-based)
-- ---------------------------------------------------------------------------

local function hasZeroBasedNeonKeys(raw)
	return raw[0] ~= nil or raw['0'] ~= nil
end

local function getLegacyNeonValue(raw, legacyIndex)
	if hasZeroBasedNeonKeys(raw) then
		local value = raw[legacyIndex]
		if value == nil then
			value = raw[tostring(legacyIndex)]
		end

		return value
	end

	local shiftedIndex = legacyIndex + 1
	local value = raw[shiftedIndex]
	if value == nil then
		value = raw[tostring(shiftedIndex)]
	end

	return value
end

local function normalizeNeonEnabled(raw)
	raw = type(raw) == 'table' and raw or {}
	local normalized = {}

	for side, legacyIndex in pairs(NEON_SIDE_TO_LEGACY_INDEX) do
		local value = raw[side]
		if value == nil then
			value = getLegacyNeonValue(raw, legacyIndex)
		end

		normalized[side] = toBoolean(value)
	end

	return normalized
end

-- ---------------------------------------------------------------------------
-- UI helpers
-- ---------------------------------------------------------------------------

local function showEditorMessage(message)
	BeginTextCommandThefeedPost('STRING')
	AddTextComponentSubstringPlayerName(message)
	EndTextCommandThefeedPostTicker(false, false)
end

local function getCurrentVehicle()
	local ped = PlayerPedId()
	if not IsPedInAnyVehicle(ped, false) then
		return nil
	end

	local vehicle = GetVehiclePedIsIn(ped, false)
	if not vehicle or vehicle == 0 then
		return nil
	end

	if GetPedInVehicleSeat(vehicle, -1) ~= ped then
		return nil
	end

	return vehicle
end

-- ---------------------------------------------------------------------------
-- Preview camera
-- ---------------------------------------------------------------------------

local function resetCameraKeys()
	cameraState.w = false
	cameraState.s = false
	cameraState.a = false
	cameraState.d = false
	cameraState.q = false
	cameraState.e = false
end

local function getCameraDistanceMultiplier()
	local multiplier = tonumber(lsrpConfig and lsrpConfig.vehicleEditorCameraDistanceMultiplier)
	if not multiplier then
		return 0.75
	end

	return clamp(multiplier, 0.25, 2.5)
end

local function getVehicleCameraMetrics(vehicle)
	local minDim, maxDim = GetModelDimensions(GetEntityModel(vehicle))
	local sizeX = math.abs(maxDim.x - minDim.x)
	local sizeY = math.abs(maxDim.y - minDim.y)
	local sizeZ = math.abs(maxDim.z - minDim.z)

	local focus = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, 0.0, sizeZ * 0.55)
	local baseDistance = clamp(math.max(sizeX, sizeY) * 2.3, 4.0, 9.0)
	local distance = (baseDistance * getCameraDistanceMultiplier()) + CAMERA_DISTANCE_OFFSET
	local defaultHeight = clamp(sizeZ * 0.25, 0.6, 1.5)

	return focus, distance, defaultHeight
end

local function getCameraDistanceBounds(suggestedDistance)
	local minDistance = clamp(suggestedDistance * 0.45, 2.25, 6.0)
	local maxDistance = clamp(suggestedDistance * 2.2, 7.5, 20.0)

	if maxDistance < minDistance + 1.0 then
		maxDistance = minDistance + 1.0
	end

	return minDistance, maxDistance
end

local function updatePreviewCamera()
	if not previewCam then
		return
	end

	local vehicle = getCurrentVehicle()
	if not vehicle then
		return
	end

	local focus, suggestedDistance = getVehicleCameraMetrics(vehicle)
	if not cameraState.distance or cameraState.distance <= 0.0 then
		cameraState.distance = suggestedDistance
	end

	local minDistance, maxDistance = getCameraDistanceBounds(suggestedDistance)
	cameraState.distance = clamp(cameraState.distance, minDistance, maxDistance)

	local angleRadians = math.rad(cameraState.angle)
	local camX = focus.x + math.cos(angleRadians) * cameraState.distance
	local camY = focus.y + math.sin(angleRadians) * cameraState.distance
	local camZ = focus.z + cameraState.height

	SetCamCoord(previewCam, camX, camY, camZ)
	PointCamAtCoord(previewCam, focus.x, focus.y, focus.z)
end

local function startPreviewCamera()
	local vehicle = getCurrentVehicle()
	if not vehicle then
		return false
	end

	local _, suggestedDistance, defaultHeight = getVehicleCameraMetrics(vehicle)
	local minDistance, maxDistance = getCameraDistanceBounds(suggestedDistance)
	cameraState.angle = GetEntityHeading(vehicle) + 180.0
	cameraState.distance = clamp(suggestedDistance, minDistance, maxDistance)
	cameraState.height = defaultHeight

	if previewCam then
		DestroyCam(previewCam, false)
		previewCam = nil
	end

	previewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
	SetCamActive(previewCam, true)
	RenderScriptCams(true, true, 250, true, true)
	updatePreviewCamera()

	return true
end

local function stopPreviewCamera()
	if previewCam then
		RenderScriptCams(false, true, 250, true, true)
		DestroyCam(previewCam, false)
		previewCam = nil
	end
end

local function getVehicleDisplayName(modelHash)
	local displayName = GetDisplayNameFromVehicleModel(modelHash)
	local label = GetLabelText(displayName)

	if type(label) == 'string' and label ~= '' and label ~= 'NULL' then
		return label
	end

	if type(displayName) == 'string' and displayName ~= '' and displayName ~= 'NULL' then
		return displayName
	end

	return tostring(modelHash)
end

-- ---------------------------------------------------------------------------
-- Vehicle state capture & apply
-- ---------------------------------------------------------------------------

-- Reads all tracked mod types, toggle mods, colors, neon, and wheel settings from
-- the vehicle into a serializable table. Used to populate the NUI and as the
-- initial state for the revert operation.
local function captureVehicleState(vehicle)
	SetVehicleModKit(vehicle, 0)

	local mods = {}
	for _, modType in ipairs(MOD_TYPES) do
		local modIndex = GetVehicleMod(vehicle, modType)
		local modCount = GetNumVehicleMods(vehicle, modType)

		if modType == 48 then
			local liveryCount = GetVehicleLiveryCount(vehicle)

			if (not modCount or modCount <= 0) and liveryCount and liveryCount > 0 then
				modCount = liveryCount
				modIndex = GetVehicleLivery(vehicle)
			elseif liveryCount and liveryCount > modCount and modIndex < 0 then
				modCount = liveryCount
				modIndex = GetVehicleLivery(vehicle)
			end
		end

		mods[modType] = {
			index = toInteger(modIndex, -1),
			variation = GetVehicleModVariation(vehicle, modType) == true,
			count = math.max(0, toInteger(modCount, 0))
		}
	end

	local toggleMods = {}
	for _, modType in ipairs(TOGGLE_MOD_TYPES) do
		toggleMods[modType] = IsToggleModOn(vehicle, modType) == true
	end

	local primary, secondary = GetVehicleColours(vehicle)
	local pearlescent, wheel = GetVehicleExtraColours(vehicle)
	local wheelType = GetVehicleWheelType(vehicle)
	local windowTint = GetVehicleWindowTint(vehicle)

	local xenonColor = -1
	if type(GetVehicleXenonLightsColor) == 'function' then
		xenonColor = GetVehicleXenonLightsColor(vehicle)

		if xenonColor < -1 or xenonColor > 13 then
			xenonColor = -1
		end
	end

	local tyreSmokeR, tyreSmokeG, tyreSmokeB = GetVehicleTyreSmokeColor(vehicle)
	local neonR, neonG, neonB = GetVehicleNeonLightsColour(vehicle)
	local isPrimaryCustom = type(GetIsVehiclePrimaryColourCustom) == 'function' and GetIsVehiclePrimaryColourCustom(vehicle) == true
	local isSecondaryCustom = type(GetIsVehicleSecondaryColourCustom) == 'function' and GetIsVehicleSecondaryColourCustom(vehicle) == true
	local customPrimaryR, customPrimaryG, customPrimaryB = 0, 0, 0
	local customSecondaryR, customSecondaryG, customSecondaryB = 0, 0, 0

	if isPrimaryCustom and type(GetVehicleCustomPrimaryColour) == 'function' then
		customPrimaryR, customPrimaryG, customPrimaryB = GetVehicleCustomPrimaryColour(vehicle)
	end

	if isSecondaryCustom and type(GetVehicleCustomSecondaryColour) == 'function' then
		customSecondaryR, customSecondaryG, customSecondaryB = GetVehicleCustomSecondaryColour(vehicle)
	end

	local neonEnabled = {}
	for side, index in pairs(NEON_SIDE_TO_NATIVE_INDEX) do
		neonEnabled[side] = toBoolean(IsVehicleNeonLightEnabled(vehicle, index))
	end

	local model = GetEntityModel(vehicle)

	return {
		model = tostring(model),
		displayName = getVehicleDisplayName(model),
		mods = mods,
		toggleMods = toggleMods,
		colors = {
			primary = primary,
			secondary = secondary,
			pearlescent = pearlescent,
			wheel = wheel,
			wheelType = wheelType,
			windowTint = windowTint,
			xenonColor = xenonColor,
			tyreSmoke = {
				r = tyreSmokeR,
				g = tyreSmokeG,
				b = tyreSmokeB
			},
			neon = {
				r = neonR,
				g = neonG,
				b = neonB
			},
			neonEnabled = neonEnabled,
			custom = {
				primary = {
					enabled = isPrimaryCustom,
					r = clamp(toInteger(customPrimaryR, 0), 0, 255),
					g = clamp(toInteger(customPrimaryG, 0), 0, 255),
					b = clamp(toInteger(customPrimaryB, 0), 0, 255)
				},
				secondary = {
					enabled = isSecondaryCustom,
					r = clamp(toInteger(customSecondaryR, 0), 0, 255),
					g = clamp(toInteger(customSecondaryG, 0), 0, 255),
					b = clamp(toInteger(customSecondaryB, 0), 0, 255)
				}
			}
		}
	}
end

local function getStateForNui()
	local vehicle = getCurrentVehicle()
	if not vehicle then
		return nil
	end

	return captureVehicleState(vehicle)
end

local function getSafeModIndex(vehicle, modType, rawIndex)
	local index = toInteger(rawIndex, -1)
	if index < -1 then
		index = -1
	end

	local modCount = GetNumVehicleMods(vehicle, modType)
	if modType == 48 and modCount <= 0 then
		local liveryCount = GetVehicleLiveryCount(vehicle)
		if liveryCount and liveryCount > 0 then
			modCount = liveryCount
			if index < 0 then
				index = 0
			end
		end
	end

	if modCount <= 0 then
		return -1
	end

	if index >= modCount then
		index = modCount - 1
	end

	return index
end

-- Applies a single mod type to the vehicle, with livery-sync for mod 48.
local function applyVehicleMod(vehicle, modType, modData)
	SetVehicleModKit(vehicle, 0)

	if TOGGLE_MOD_LOOKUP[modType] then
		ToggleVehicleMod(vehicle, modType, modData.enabled == true)
		return true
	end

	if modType == 48 and GetNumVehicleMods(vehicle, 48) <= 0 then
		local liveryCount = GetVehicleLiveryCount(vehicle)
		if liveryCount and liveryCount > 0 then
			local liveryIndex = clamp(toInteger(modData.index, 0), 0, liveryCount - 1)
			SetVehicleLivery(vehicle, liveryIndex)
			return true
		end
	end

	local safeIndex = getSafeModIndex(vehicle, modType, modData.index)
	local variation = modData.variation == true
	SetVehicleMod(vehicle, modType, safeIndex, variation)

	if modType == 48 then
		local liveryCount = GetVehicleLiveryCount(vehicle)
		if liveryCount and liveryCount > 0 then
			local liveryIndex = safeIndex
			if liveryIndex < 0 then
				liveryIndex = 0
			end

			if liveryIndex >= liveryCount then
				liveryIndex = liveryCount - 1
			end

			SetVehicleLivery(vehicle, liveryIndex)
		end
	end

	return true
end

local function getSafeColor(value)
	return clamp(toInteger(value, 0), 0, 255)
end

local function getVehicleColorIndexMax(vehicle)
	if type(GetNumVehicleColours) ~= 'function' then
		return 255
	end

	local ok, colorCount = pcall(GetNumVehicleColours, vehicle)
	if not ok then
		return 255
	end

	colorCount = toInteger(colorCount, 0)
	if colorCount <= 0 then
		return 255
	end

	return colorCount - 1
end

local function getSafeColorIndex(value, maxIndex)
	local colorMax = toInteger(maxIndex, 255)
	if colorMax < 0 then
		colorMax = 0
	end

	return clamp(toInteger(value, 0), 0, colorMax)
end

local function getSafeRgb(raw)
	raw = type(raw) == 'table' and raw or {}

	return {
		r = getSafeColor(raw.r or raw[1]),
		g = getSafeColor(raw.g or raw[2]),
		b = getSafeColor(raw.b or raw[3])
	}
end

local function reapplyWheelModsForCurrentType(vehicle, wheelTypeChanged)
	SetVehicleModKit(vehicle, 0)

	local frontIndex = GetVehicleMod(vehicle, 23)
	local frontVariation = GetVehicleModVariation(vehicle, 23) == true
	local frontCount = GetNumVehicleMods(vehicle, 23)

	if wheelTypeChanged and frontCount > 0 and frontIndex < 0 then
		frontIndex = 0
	end

	if frontCount > 0 and frontIndex >= frontCount then
		frontIndex = frontCount - 1
	end

	if frontCount > 0 then
		SetVehicleMod(vehicle, 23, -1, false)
		SetVehicleMod(vehicle, 23, frontIndex, frontVariation)
	end

	local rearCount = GetNumVehicleMods(vehicle, 24)
	if rearCount > 0 then
		local rearIndex = GetVehicleMod(vehicle, 24)
		local rearVariation = GetVehicleModVariation(vehicle, 24) == true

		if wheelTypeChanged and rearIndex < 0 then
			rearIndex = 0
		end

		if rearIndex >= rearCount then
			rearIndex = rearCount - 1
		end

		SetVehicleMod(vehicle, 24, -1, false)
		SetVehicleMod(vehicle, 24, rearIndex, rearVariation)
	end
end

-- Applies the full colors block (paint, pearlescent, wheel type, window tint,
-- xenon, tyre smoke, neon color, neon enable flags) to the vehicle.
local function applyColorData(vehicle, rawColors)
	local colors = type(rawColors) == 'table' and rawColors or {}
	local colorMax = getVehicleColorIndexMax(vehicle)

	if type(ClearVehicleCustomPrimaryColour) == 'function' then
		ClearVehicleCustomPrimaryColour(vehicle)
	end

	if type(ClearVehicleCustomSecondaryColour) == 'function' then
		ClearVehicleCustomSecondaryColour(vehicle)
	end

	local primary = getSafeColorIndex(colors.primary, colorMax)
	local secondary = getSafeColorIndex(colors.secondary, colorMax)
	SetVehicleColours(vehicle, primary, secondary)

	local custom = type(colors.custom) == 'table' and colors.custom or {}
	local customPrimary = type(custom.primary) == 'table' and custom.primary or {}
	local customSecondary = type(custom.secondary) == 'table' and custom.secondary or {}

	if toBoolean(customPrimary.enabled) and type(SetVehicleCustomPrimaryColour) == 'function' then
		local primaryRgb = getSafeRgb(customPrimary)
		SetVehicleCustomPrimaryColour(vehicle, primaryRgb.r, primaryRgb.g, primaryRgb.b)
	end

	if toBoolean(customSecondary.enabled) and type(SetVehicleCustomSecondaryColour) == 'function' then
		local secondaryRgb = getSafeRgb(customSecondary)
		SetVehicleCustomSecondaryColour(vehicle, secondaryRgb.r, secondaryRgb.g, secondaryRgb.b)
	end

	local pearlescent = getSafeColorIndex(colors.pearlescent, colorMax)
	local wheel = getSafeColorIndex(colors.wheel, colorMax)
	SetVehicleExtraColours(vehicle, pearlescent, wheel)

	SetVehicleModKit(vehicle, 0)
	local previousWheelType = GetVehicleWheelType(vehicle)
	local wheelType = clamp(toInteger(colors.wheelType, 0), 0, 12)
	SetVehicleWheelType(vehicle, wheelType)
	reapplyWheelModsForCurrentType(vehicle, previousWheelType ~= wheelType)

	local windowTint = clamp(toInteger(colors.windowTint, -1), -1, 6)
	SetVehicleWindowTint(vehicle, windowTint)

	local xenonColor = clamp(toInteger(colors.xenonColor, -1), -1, 13)
	if xenonColor >= 0 and type(SetVehicleXenonLightsColor) == 'function' then
		ToggleVehicleMod(vehicle, 22, true)
		SetVehicleXenonLightsColor(vehicle, xenonColor)
	elseif xenonColor < 0 then
		ToggleVehicleMod(vehicle, 22, false)
	end

	local tyreSmoke = getSafeRgb(colors.tyreSmoke)
	SetVehicleTyreSmokeColor(vehicle, tyreSmoke.r, tyreSmoke.g, tyreSmoke.b)

	local neon = getSafeRgb(colors.neon)
	SetVehicleNeonLightsColour(vehicle, neon.r, neon.g, neon.b)

	local neonEnabled = normalizeNeonEnabled(colors.neonEnabled)
	for side, nativeIndex in pairs(NEON_SIDE_TO_NATIVE_INDEX) do
		SetVehicleNeonLightEnabled(vehicle, nativeIndex, toBoolean(neonEnabled[side]))
	end

	return true
end

local function applyVehicleSetup(vehicle, setup)
	if type(setup) ~= 'table' then
		return false
	end

	SetVehicleModKit(vehicle, 0)

	if type(setup.toggleMods) == 'table' then
		for _, modType in ipairs(TOGGLE_MOD_TYPES) do
			local value = setup.toggleMods[modType]
			if value == nil then
				value = setup.toggleMods[tostring(modType)]
			end

			ToggleVehicleMod(vehicle, modType, value == true)
		end
	end

	if type(setup.mods) == 'table' then
		for _, modType in ipairs(MOD_TYPES) do
			local modData = setup.mods[modType] or setup.mods[tostring(modType)] or {}
			applyVehicleMod(vehicle, modType, {
				index = modData.index,
				variation = modData.variation == true
			})
		end
	end

	applyColorData(vehicle, setup.colors)
	return true
end

local function safeNativeCall(nativeFn, ...)
	if type(nativeFn) ~= 'function' then
		return false
	end

	local ok = pcall(nativeFn, ...)
	return ok
end

-- Fixes body, engine, tank, doors, tyres, windows, and fuel. Removes dirt.
local function repairVehicleCompletely(vehicle)
	safeNativeCall(SetVehicleFixed, vehicle)
	safeNativeCall(SetVehicleDeformationFixed, vehicle)
	safeNativeCall(SetVehicleDirtLevel, vehicle, 0.0)
	safeNativeCall(SetVehicleUndriveable, vehicle, false)
	safeNativeCall(SetVehicleEngineOn, vehicle, true, true, false)
	safeNativeCall(SetVehicleEngineHealth, vehicle, 1000.0)
	safeNativeCall(SetVehicleBodyHealth, vehicle, 1000.0)
	safeNativeCall(SetVehiclePetrolTankHealth, vehicle, 1000.0)
	safeNativeCall(SetVehicleFuelLevel, vehicle, 100.0)

	for doorId = 0, 5 do
		safeNativeCall(SetVehicleDoorFixed, vehicle, doorId)
	end

	for wheelId = 0, 7 do
		safeNativeCall(SetVehicleTyreFixed, vehicle, wheelId)
	end

	for windowId = 0, 7 do
		safeNativeCall(FixVehicleWindow, vehicle, windowId)
	end

	safeNativeCall(WashDecalsFromVehicle, vehicle, 1.0)
	safeNativeCall(SetVehicleOnGroundProperly, vehicle)
end

-- ---------------------------------------------------------------------------
-- Editor open/close
-- ---------------------------------------------------------------------------

local function closeEditor()
	if not isEditorOpen then
		return
	end

	isEditorOpen = false
	pendingDeletion = nil
	resetCameraKeys()
	stopPreviewCamera()
	SetNuiFocus(false, false)

	if type(SetNuiFocusKeepInput) == 'function' then
		SetNuiFocusKeepInput(false)
	end

	SendNUIMessage({ type = 'hide' })
	TriggerEvent('lsrp_vehicleeditor:closed')
end

local function openEditor()
	if isEditorOpen then
		return
	end

	local vehicle = getCurrentVehicle()
	if not vehicle then
		showEditorMessage('~r~Vehicle editor:~s~ You must be in the driver seat.')
		return
	end

	local repairedOk, repairErr = pcall(repairVehicleCompletely, vehicle)
	if not repairedOk then
		print(('[lsrp_vehicleeditor] vehicle repair failed: %s'):format(tostring(repairErr)))
	end

	local capturedState = captureVehicleState(vehicle)
	if not capturedState then
		showEditorMessage('~r~Vehicle editor:~s~ Unable to read vehicle state.')
		return
	end

	resetCameraKeys()
	if not startPreviewCamera() then
		showEditorMessage('~r~Vehicle editor:~s~ Failed to start preview camera.')
		return
	end

	isEditorOpen = true
	initialSetup = capturedState

	SetNuiFocus(true, true)
	if type(SetNuiFocusKeepInput) == 'function' then
		SetNuiFocusKeepInput(false)
	end

	SendNUIMessage({ type = 'show' })
	TriggerEvent('lsrp_vehicleeditor:opened')
end

local function toggleEditor()
	if isEditorOpen then
		closeEditor()
		return
	end

	openEditor()
end

-- ---------------------------------------------------------------------------
-- Server request/response bridge
-- ---------------------------------------------------------------------------

local function awaitServerResponse(action, payload, timeoutMs)
	if GetResourceState('lsrp_framework') ~= 'started' then
		return { ok = false, error = 'framework_unavailable' }
	end

	local ok, response = pcall(function()
		return exports['lsrp_framework']:triggerServerCallback('lsrp_vehicleeditor:request', {
			action = tostring(action or ''),
			data = type(payload) == 'table' and payload or {}
		}, timeoutMs or 5000)
	end)

	if not ok or type(response) ~= 'table' then
		return { ok = false, error = 'framework_callback_failed' }
	end

	return response
end

RegisterNUICallback('getVehicleState', function(_, cb)
	local state = getStateForNui()
	if not state then
		cb({ ok = false, error = 'not_in_vehicle' })
		return
	end

	cb({
		ok = true,
		state = state,
		modLabels = MOD_LABELS,
		modTypes = MOD_TYPES,
		toggleModTypes = TOGGLE_MOD_TYPES,
		slotRange = { min = MIN_SLOT, max = MAX_SLOT }
	})
end)

RegisterNUICallback('applyMod', function(data, cb)
	local vehicle = getCurrentVehicle()
	local modType = toInteger(data and data.modType, nil)

	if not vehicle or not modType or not ALLOWED_MOD_LOOKUP[modType] then
		cb({ ok = false, error = 'invalid_vehicle_or_mod' })
		return
	end

	applyVehicleMod(vehicle, modType, {
		index = data and data.index,
		variation = data and data.variation == true
	})

	cb({ ok = true, state = captureVehicleState(vehicle) })
end)

RegisterNUICallback('applyToggleMod', function(data, cb)
	local vehicle = getCurrentVehicle()
	local modType = toInteger(data and data.modType, nil)

	if not vehicle or not modType or not TOGGLE_MOD_LOOKUP[modType] then
		cb({ ok = false, error = 'invalid_toggle_mod' })
		return
	end

	applyVehicleMod(vehicle, modType, {
		enabled = data and data.enabled == true
	})

	cb({ ok = true, state = captureVehicleState(vehicle) })
end)

RegisterNUICallback('applyColorData', function(data, cb)
	local vehicle = getCurrentVehicle()
	if not vehicle then
		cb({ ok = false, error = 'not_in_vehicle' })
		return
	end

	applyColorData(vehicle, data and data.colors)
	cb({ ok = true, state = captureVehicleState(vehicle) })
end)

RegisterNUICallback('applySetup', function(data, cb)
	local vehicle = getCurrentVehicle()
	if not vehicle then
		cb({ ok = false, error = 'not_in_vehicle' })
		return
	end

	if not applyVehicleSetup(vehicle, data and data.setup) then
		cb({ ok = false, error = 'invalid_setup' })
		return
	end

	cb({ ok = true, state = captureVehicleState(vehicle) })
end)

RegisterNUICallback('revertVehicle', function(_, cb)
	local vehicle = getCurrentVehicle()
	if not vehicle then
		cb({ ok = false, error = 'not_in_vehicle' })
		return
	end

	if initialSetup then
		applyVehicleSetup(vehicle, initialSetup)
	end

	cb({ ok = true, state = captureVehicleState(vehicle) })
end)

RegisterNUICallback('listSetups', function(_, cb)
	local response = awaitServerResponse('listSetups', {}, 5000)
	cb(response and response.data or {})
end)

RegisterNUICallback('getSetup', function(data, cb)
	local response = awaitServerResponse('getSetup', {
		slot = data and data.slot
	}, 5000)

	if response and response.ok and type(response.data) == 'table' then
		response.slot = response.slot or response.data.slot
		response.name = response.name or response.data.name
		response.setup = response.setup or response.data.setup
	end

	cb(response or { ok = false, error = 'no_response' })
end)

RegisterNUICallback('saveSetup', function(data, cb)
	local response = awaitServerResponse('saveSetup', {
		slot = data and data.slot,
		name = data and data.name,
		setup = data and data.setup
	}, 12000)

	cb(response or { ok = false, error = 'no_response' })
end)

RegisterNUICallback('deleteSetup', function(data, cb)
	local slot = toInteger(data and data.slot, nil)
	if not slot or slot < MIN_SLOT or slot > MAX_SLOT then
		cb({ ok = false, error = 'invalid_slot' })
		return
	end

	pendingDeletion = {
		slot = slot,
		startTime = GetGameTimer(),
		timeout = 10000,
		callback = cb
	}

	showEditorMessage('~g~Press ~s~Y ~g~to confirm deletion of slot ' .. tostring(slot) .. ', ~s~N ~g~to cancel')
end)

local function processDeleteConfirmation(key)
	if not pendingDeletion then
		return
	end

	local key = string.upper(tostring(key or ''))
	local elapsed = GetGameTimer() - pendingDeletion.startTime

	if elapsed > pendingDeletion.timeout then
		showEditorMessage('~r~Deletion cancelled (timeout)')
		pendingDeletion.callback({ ok = true })
		pendingDeletion = nil
		return
	end

	if key == 'Y' then
		showEditorMessage('~g~Deleting setup...')
		local response = awaitServerResponse('deleteSetup', {
			slot = pendingDeletion.slot
		}, 5000)

		if response and response.ok then
			SetTimeout(500, function()
				SendNUIMessage({ type = 'refreshSetups' })
			end)
		end

		pendingDeletion.callback(response or { ok = false, error = 'no_response' })
		pendingDeletion = nil
		return
	end

	if key == 'N' then
		showEditorMessage('~r~Deletion cancelled')
		pendingDeletion.callback({ ok = true })
		pendingDeletion = nil
		return
	end
end

RegisterNUICallback('closeNUI', function(_, cb)
	closeEditor()
	cb({ ok = true })
end)

RegisterNUICallback('cameraKey', function(data, cb)
	local key = data and tostring(data.key or ''):lower() or ''
	local down = data and data.down == true

	if key == 'w' or key == 's' or key == 'a' or key == 'd' or key == 'q' or key == 'e' then
		cameraState[key] = down
	end

	cb({ ok = true })
end)

RegisterNUICallback('nuiError', function(data, cb)
	local msg = data and data.message or 'unknown error'
	local src = data and data.source or 'nui'
	local line = data and data.lineno or 0
	print(('[lsrp_vehicleeditor] NUI error: %s (%s:%s)'):format(tostring(msg), tostring(src), tostring(line)))
	cb({ ok = true })
end)

CreateThread(function()
	while true do
		if isEditorOpen then
			local vehicle = getCurrentVehicle()
			if not vehicle then
				closeEditor()
				showEditorMessage('~r~Vehicle editor:~s~ You must stay in the driver seat.')
				Wait(250)
			else
				DisableAllControlActions(0)
				HideHudAndRadarThisFrame()

				if IsDisabledControlJustPressed(0, 200) then
					closeEditor()
				end

				if pendingDeletion then
					if IsDisabledControlJustPressed(0, 246) then
						processDeleteConfirmation('Y')
					elseif IsDisabledControlJustPressed(0, 249) then
						processDeleteConfirmation('N')
					end
				end

				if cameraState.w then
					cameraState.height = math.min(cameraState.height + CAMERA_HEIGHT_STEP, CAMERA_MAX_HEIGHT)
				end

				if cameraState.s then
					cameraState.height = math.max(cameraState.height - CAMERA_HEIGHT_STEP, CAMERA_MIN_HEIGHT)
				end

				if cameraState.a then
					cameraState.angle = cameraState.angle - CAMERA_ROTATE_STEP
				end

				if cameraState.d then
					cameraState.angle = cameraState.angle + CAMERA_ROTATE_STEP
				end

				if cameraState.q then
					cameraState.distance = cameraState.distance - CAMERA_DISTANCE_STEP
				end

				if cameraState.e then
					cameraState.distance = cameraState.distance + CAMERA_DISTANCE_STEP
				end

				updatePreviewCamera()
				Wait(0)
			end
		else
			Wait(250)
		end
	end
end)

RegisterCommand('vehicleeditor', function()
	toggleEditor()
end, false)

RegisterCommand('veditor', function()
	toggleEditor()
end, false)

RegisterNetEvent('lsrp_vehicleeditor:open', function()
	openEditor()
end)

RegisterNetEvent('lsrp_vehicleeditor:close', function()
	closeEditor()
end)

RegisterNetEvent('lsrp_vehicleeditor:toggle', function()
	toggleEditor()
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	closeEditor()
	stopPreviewCamera()
end)
