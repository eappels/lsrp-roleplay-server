-- LSRP Ped Editor - Client Script
--
-- Provides an in-game character customisation UI (model + clothing components).
-- Outfits (model + component variations) are stored server-side per license in
-- up to 10 named slots.  The most recently saved outfit is automatically restored
-- when the player spawns.
--
-- Commands / key bindings:
--   /ped  or  /pededitor  - toggle editor
--   /mask  or  Z          - toggle mask on/off (+mask_toggle)
--
-- Net events received:
--   lsrp_pededitor:open   - open the editor remotely
--   lsrp_pededitor:close  - close the editor remotely
--   lsrp_pededitor:toggle - toggle the editor remotely
--
-- Server communication (request/response):
--   request:  lsrp_pededitor:serverRequest(requestId, action, data)
--   response: lsrp_pededitor:serverResponse(requestId, response)
--   Actions: listOutfits, getOutfit, getSpawnOutfit, saveOutfit, deleteOutfit

local COMPONENT_MIN = 0
local COMPONENT_MAX = 11
local MASK_COMPONENT_ID = 1
local MASK_ANIM_DICT = 'mp_masks@standard_car@ds@'
local MASK_ANIM_NAME = 'put_on_mask'
local MASK_ANIM_DURATION_MS = 650
local MASK_SWAP_DELAY_MS = 260
local MASK_TOGGLE_COOLDOWN_MS = 300
local OUTFIT_SLOT_MIN = 1
local OUTFIT_SLOT_MAX = 10
local DEFAULT_AUTO_RESTORE_DELAY_MS = 300
local MODEL_HASH_INT32_MAX = 2147483647
local MODEL_HASH_UINT32_WRAP = 4294967296

local isEditorOpen = false
local isCharacterCreationMode = false
local previewCam = nil
local initialAppearance = nil

local requestCounter = 0
local pendingRequests = {}
local lastMaskByModel = {}
local maskToggleBusy = false
local lastMaskToggleAt = 0
local autoRestoreNonce = 0

local cameraState = {
	w = false,
	s = false,
	a = false,
	d = false,
	angle = 180.0,
	height = 0.65,
	distance = 2.15
}

-- ---------------------------------------------------------------------------
-- Utility helpers
-- ---------------------------------------------------------------------------

local function toNonNegativeInt(value)
	local number = tonumber(value) or 0
	number = math.floor(number)

	if number < 0 then
		number = 0
	end

	return number
end

-- UV32 -> int32 so GTA model hashes stay consistent across Lua number conversions.
local function normalizeModelHash(value)
	local number = tonumber(value)
	if not number then
		return nil
	end

	number = math.floor(number)
	if number > MODEL_HASH_INT32_MAX then
		number = number - MODEL_HASH_UINT32_WRAP
	end

	return number
end

-- ---------------------------------------------------------------------------
-- Auto-restore config readers
-- ---------------------------------------------------------------------------

local function isAutoRestoreEnabled()
	if not lsrpConfig then
		return true
	end

	return lsrpConfig.pedEditorAutoRestoreEnabled ~= false
end

local function getAutoRestoreSlot()
	local configuredSlot = lsrpConfig and lsrpConfig.pedEditorAutoRestoreSlot
	if configuredSlot == nil then
		return nil
	end

	local slot = tonumber(configuredSlot)
	if not slot then
		return nil
	end

	slot = math.floor(slot)
	if slot < OUTFIT_SLOT_MIN or slot > OUTFIT_SLOT_MAX then
		return nil
	end

	return slot
end

local function getAutoRestoreDelayMs()
	local configuredDelay = tonumber(lsrpConfig and lsrpConfig.pedEditorAutoRestoreDelayMs)
	if not configuredDelay then
		return DEFAULT_AUTO_RESTORE_DELAY_MS
	end

	configuredDelay = math.floor(configuredDelay)
	if configuredDelay < 0 then
		return 0
	end

	return configuredDelay
end

local function toModelHash(model)
	if type(model) == 'number' then
		return normalizeModelHash(model)
	end

	if type(model) == 'string' and model ~= '' then
		local asNumber = tonumber(model)
		if asNumber then
			return normalizeModelHash(asNumber)
		end

		return normalizeModelHash(GetHashKey(model))
	end

	return nil
end

local function requestModel(modelHash)
	if not modelHash or modelHash == 0 then
		return false
	end

	if not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then
		return false
	end

	RequestModel(modelHash)
	local timeoutAt = GetGameTimer() + 10000

	while not HasModelLoaded(modelHash) do
		Wait(0)
		RequestModel(modelHash)

		if GetGameTimer() > timeoutAt then
			break
		end
	end

	return HasModelLoaded(modelHash)
end

-- ---------------------------------------------------------------------------
-- Ped component helpers
-- ---------------------------------------------------------------------------

-- Clamps drawable/texture indices to the valid range for this ped component.
local function getSafeComponent(ped, componentId, drawable, texture)
	local maxDrawable = GetNumberOfPedDrawableVariations(ped, componentId)
	if maxDrawable <= 0 then
		return 0, 0
	end

	local safeDrawable = toNonNegativeInt(drawable)
	if safeDrawable >= maxDrawable then
		safeDrawable = maxDrawable - 1
	end

	local maxTexture = GetNumberOfPedTextureVariations(ped, componentId, safeDrawable)
	local safeTexture = toNonNegativeInt(texture)

	if maxTexture <= 0 then
		safeTexture = 0
	elseif safeTexture >= maxTexture then
		safeTexture = maxTexture - 1
	end

	return safeDrawable, safeTexture
end

local function captureComponents(ped)
	local components = {}

	for componentId = COMPONENT_MIN, COMPONENT_MAX do
		components[componentId] = {
			drawable = GetPedDrawableVariation(ped, componentId),
			texture = GetPedTextureVariation(ped, componentId)
		}
	end

	return components
end

local function captureAppearance()
	local ped = PlayerPedId()

	return {
		model = GetEntityModel(ped),
		components = captureComponents(ped)
	}
end

local function applyComponents(components)
	local ped = PlayerPedId()
	components = type(components) == 'table' and components or {}

	for componentId = COMPONENT_MIN, COMPONENT_MAX do
		local component = components[componentId] or components[tostring(componentId)] or {}
		local drawable, texture = getSafeComponent(ped, componentId, component.drawable, component.texture)
		SetPedComponentVariation(ped, componentId, drawable, texture, 0)
	end
end

local function applyModel(model)
	local modelHash = toModelHash(model)
	if not modelHash then
		return false
	end

	if not requestModel(modelHash) then
		return false
	end

	SetPlayerModel(PlayerId(), modelHash)
	SetModelAsNoLongerNeeded(modelHash)
	SetPedDefaultComponentVariation(PlayerPedId())

	return true
end

local function applyAppearance(appearance)
	if type(appearance) ~= 'table' then
		return false
	end

	local currentModel = GetEntityModel(PlayerPedId())
	local targetModel = toModelHash(appearance.model)
	local modelChanged = targetModel and currentModel ~= targetModel

	if modelChanged then
		local changed = applyModel(targetModel)
		if not changed then
			return false
		end
	end

	applyComponents(appearance.components)
	return true
end

local function applyOutfit(outfit)
	if type(outfit) ~= 'table' then
		return false
	end

	return applyAppearance({
		model = outfit.model,
		components = outfit.comps
	})
end

local function getMaskModelKey(ped)
	return tostring(GetEntityModel(ped) or 0)
end

local function requestAnimDict(dict, timeoutMs)
	if HasAnimDictLoaded(dict) then
		return true
	end

	RequestAnimDict(dict)
	local timeoutAt = GetGameTimer() + (timeoutMs or 1500)

	while not HasAnimDictLoaded(dict) and GetGameTimer() < timeoutAt do
		RequestAnimDict(dict)
		Wait(0)
	end

	return HasAnimDictLoaded(dict)
end

-- ---------------------------------------------------------------------------
-- Mask toggle (component slot 1)
-- ---------------------------------------------------------------------------

-- Returns the target drawable/texture to apply next: removes mask if one is on,
-- restores the last worn mask, or picks the first available non-zero drawable.
local function resolveMaskToggleTarget(ped)
	local modelKey = getMaskModelKey(ped)
	local currentDrawable = GetPedDrawableVariation(ped, MASK_COMPONENT_ID)
	local currentTexture = GetPedTextureVariation(ped, MASK_COMPONENT_ID)

	if currentDrawable > 0 then
		lastMaskByModel[modelKey] = {
			drawable = currentDrawable,
			texture = currentTexture
		}

		return getSafeComponent(ped, MASK_COMPONENT_ID, 0, 0)
	end

	local rememberedMask = lastMaskByModel[modelKey]
	if rememberedMask and (tonumber(rememberedMask.drawable) or 0) > 0 then
		return getSafeComponent(ped, MASK_COMPONENT_ID, rememberedMask.drawable, rememberedMask.texture)
	end

	local maxDrawable = GetNumberOfPedDrawableVariations(ped, MASK_COMPONENT_ID)
	if maxDrawable <= 1 then
		return nil, nil
	end

	return getSafeComponent(ped, MASK_COMPONENT_ID, 1, 0)
end

local function playMaskToggleAnimation(ped)
	if IsPedInAnyVehicle(ped, false) then
		return false
	end

	if not requestAnimDict(MASK_ANIM_DICT, 1800) then
		return false
	end

	TaskPlayAnim(ped, MASK_ANIM_DICT, MASK_ANIM_NAME, 8.0, -8.0, MASK_ANIM_DURATION_MS, 49, 0.0, false, false, false)
	return true
end

local function toggleMask()
	if isEditorOpen then
		return
	end

	if maskToggleBusy then
		return
	end

	local now = GetGameTimer()
	if (now - lastMaskToggleAt) < MASK_TOGGLE_COOLDOWN_MS then
		return
	end

	lastMaskToggleAt = now

	local ped = PlayerPedId()
	if not ped or ped <= 0 then
		return
	end

	local drawable, texture = resolveMaskToggleTarget(ped)
	if drawable == nil then
		return
	end

	maskToggleBusy = true

	CreateThread(function()
		local played = playMaskToggleAnimation(ped)

		if played then
			Wait(MASK_SWAP_DELAY_MS)
		end

		if DoesEntityExist(ped) then
			SetPedComponentVariation(ped, MASK_COMPONENT_ID, drawable, texture, 0)
		end

		if played then
			local remaining = MASK_ANIM_DURATION_MS - MASK_SWAP_DELAY_MS
			if remaining > 0 then
				Wait(remaining)
			end

			if DoesEntityExist(ped) then
				ClearPedSecondaryTask(ped)
			end
		end

		maskToggleBusy = false
	end)
end

-- ---------------------------------------------------------------------------
-- Preview camera
-- ---------------------------------------------------------------------------

local function resetCameraKeys()
	cameraState.w = false
	cameraState.s = false
	cameraState.a = false
	cameraState.d = false
end

local function updatePreviewCamera()
	if not previewCam then
		return
	end

	local ped = PlayerPedId()
	local pedCoords = GetEntityCoords(ped)
	local angleRadians = math.rad(cameraState.angle)

	local camX = pedCoords.x + math.cos(angleRadians) * cameraState.distance
	local camY = pedCoords.y + math.sin(angleRadians) * cameraState.distance
	local camZ = pedCoords.z + cameraState.height

	SetCamCoord(previewCam, camX, camY, camZ)
	PointCamAtCoord(previewCam, pedCoords.x, pedCoords.y, pedCoords.z + 0.65)
end

local function startPreviewCamera()
	local ped = PlayerPedId()
	cameraState.angle = GetEntityHeading(ped) + 180.0
	cameraState.height = 0.65

	if previewCam then
		DestroyCam(previewCam, false)
		previewCam = nil
	end

	previewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
	SetCamActive(previewCam, true)
	RenderScriptCams(true, true, 250, true, true)
	updatePreviewCamera()
end

local function stopPreviewCamera()
	if previewCam then
		RenderScriptCams(false, true, 250, true, true)
		DestroyCam(previewCam, false)
		previewCam = nil
	end
end

-- ---------------------------------------------------------------------------
-- Editor open/close
-- ---------------------------------------------------------------------------

local function closeEditor(force)
	if not isEditorOpen then
		return
	end

	if isCharacterCreationMode and force ~= true then
		return
	end

	isEditorOpen = false
	isCharacterCreationMode = false
	resetCameraKeys()
	stopPreviewCamera()
	SetNuiFocus(false, false)

	if type(SetNuiFocusKeepInput) == 'function' then
		SetNuiFocusKeepInput(false)
	end

	SendNUIMessage({ type = 'hide' })
	TriggerEvent('lsrp_pededitor:closed')
end

local function openEditor(options)
	if isEditorOpen then
		return
	end

	options = type(options) == 'table' and options or {}

	isEditorOpen = true
	isCharacterCreationMode = options.characterCreationMode == true
	initialAppearance = captureAppearance()

	SetNuiFocus(true, true)
	if type(SetNuiFocusKeepInput) == 'function' then
		SetNuiFocusKeepInput(false)
	end

	startPreviewCamera()
	SendNUIMessage({
		type = 'show',
		characterCreationMode = isCharacterCreationMode,
		spawnLabel = options.spawnLabel or 'Spawn Los Santos Airport'
	})
	TriggerEvent('lsrp_pededitor:opened')
end

local function toggleEditor()
	if isEditorOpen then
		closeEditor(false)
		return
	end

	openEditor()
end

-- ---------------------------------------------------------------------------
-- Server request/response bridge
-- ---------------------------------------------------------------------------

-- Sends a request to the server and blocks until the response arrives (or timeout).
local function awaitServerResponse(action, payload, timeoutMs)
	requestCounter = requestCounter + 1
	local requestId = requestCounter
	local responsePromise = promise.new()

	pendingRequests[requestId] = responsePromise
	TriggerServerEvent('lsrp_pededitor:serverRequest', requestId, action, payload or {})

	SetTimeout(timeoutMs or 5000, function()
		local pending = pendingRequests[requestId]
		if pending then
			pendingRequests[requestId] = nil
			pending:resolve({ ok = false, error = 'timeout' })
		end
	end)

	return Citizen.Await(responsePromise)
end

-- Fetch and apply the most recently saved outfit (or a fixed configured slot) on spawn.
local function restoreOutfitOnSpawn()
	if not isAutoRestoreEnabled() then
		return
	end

	autoRestoreNonce = autoRestoreNonce + 1
	local restoreNonce = autoRestoreNonce

	CreateThread(function()
		Wait(getAutoRestoreDelayMs())

		if restoreNonce ~= autoRestoreNonce then
			return
		end

		local payload = {}
		local slot = getAutoRestoreSlot()
		if slot then
			payload.slot = slot
		end

		local response = awaitServerResponse('getSpawnOutfit', payload, 7000)
		if restoreNonce ~= autoRestoreNonce then
			return
		end

		if not response or not response.ok or type(response.outfit) ~= 'table' then
			return
		end

		applyOutfit(response.outfit)
	end)
end

RegisterNetEvent('lsrp_pededitor:serverResponse', function(requestId, payload)
	local pending = pendingRequests[requestId]
	if not pending then
		return
	end

	pendingRequests[requestId] = nil
	pending:resolve(payload or { ok = false, error = 'empty_response' })
end)

RegisterNUICallback('getPedComponents', function(_, cb)
	cb(captureComponents(PlayerPedId()))
end)

RegisterNUICallback('getCurrentModel', function(_, cb)
	local model = GetEntityModel(PlayerPedId())
	local maleHash = GetHashKey((lsrpConfig and lsrpConfig.defaultMalePedModel) or 'mp_m_freemode_01')
	local femaleHash = GetHashKey((lsrpConfig and lsrpConfig.defaultFemalePedModel) or 'mp_f_freemode_01')

	local gender = 'other'
	if model == maleHash then
		gender = 'male'
	elseif model == femaleHash then
		gender = 'female'
	end

	cb({ gender = gender })
end)

RegisterNUICallback('applyComponent', function(data, cb)
	local ped = PlayerPedId()
	local component = tonumber(data and data.component)

	if component and component >= COMPONENT_MIN and component <= COMPONENT_MAX then
		local drawable, texture = getSafeComponent(ped, component, data.drawable, data.texture)
		SetPedComponentVariation(ped, component, drawable, texture, 0)
	end

	cb({ ok = true })
end)

RegisterNUICallback('revertPed', function(_, cb)
	if initialAppearance then
		applyAppearance(initialAppearance)
		updatePreviewCamera()
	end

	cb({ ok = true })
end)

RegisterNUICallback('applyModel', function(data, cb)
	local changed = applyModel(data and data.model)
	updatePreviewCamera()

	cb({ ok = changed })
end)

RegisterNUICallback('listOutfits', function(_, cb)
	local response = awaitServerResponse('listOutfits', {}, 5000)
	cb(response and response.data or {})
end)

RegisterNUICallback('getOutfit', function(data, cb)
	local response = awaitServerResponse('getOutfit', { slot = data and data.slot }, 5000)
	cb(response or { ok = false, error = 'no_response' })
end)

RegisterNUICallback('saveOutfit', function(data, cb)
	local response = awaitServerResponse('saveOutfit', {
		slot = data and data.slot,
		name = data and data.name,
		comps = data and data.comps
	}, 7000)

	cb(response or { ok = false, error = 'no_response' })
end)

RegisterNUICallback('deleteOutfit', function(data, cb)
	local response = awaitServerResponse('deleteOutfit', { slot = data and data.slot }, 5000)
	cb(response or { ok = false, error = 'no_response' })
end)

RegisterNUICallback('closeNUI', function(_, cb)
	if isCharacterCreationMode then
		cb({ ok = false, error = 'character_creation_active' })
		return
	end

	closeEditor(false)
	cb({ ok = true })
end)

RegisterNUICallback('finishCharacterCreation', function(_, cb)
	local response = awaitServerResponse('saveOutfit', {
		slot = 1,
		name = 'Current Look',
		comps = captureComponents(PlayerPedId())
	}, 7000)

	if not response or response.ok ~= true then
		cb(response or { ok = false, error = 'save_failed' })
		return
	end

	closeEditor(true)
	TriggerEvent('lsrp_pededitor:firstCharacterCreationFinished')
	cb({ ok = true })
end)

RegisterNUICallback('cameraKey', function(data, cb)
	local key = data and tostring(data.key or ''):lower() or ''
	local down = data and data.down == true

	if key == 'w' or key == 's' or key == 'a' or key == 'd' then
		cameraState[key] = down
	end

	cb({ ok = true })
end)

RegisterNUICallback('nuiError', function(data, cb)
	local msg = data and data.message or 'unknown error'
	local src = data and data.source or 'nui'
	local line = data and data.lineno or 0
	print(('[lsrp_pededitor] NUI error: %s (%s:%s)'):format(tostring(msg), tostring(src), tostring(line)))
	cb({ ok = true })
end)

CreateThread(function()
	while true do
		if isEditorOpen then
			DisableAllControlActions(0)
			HideHudAndRadarThisFrame()

			if not isCharacterCreationMode and IsDisabledControlJustPressed(0, 200) then
				closeEditor(false)
			end

			if cameraState.w then
				cameraState.height = math.min(cameraState.height + 0.02, 1.65)
			end

			if cameraState.s then
				cameraState.height = math.max(cameraState.height - 0.02, 0.05)
			end

			if cameraState.a then
				cameraState.angle = cameraState.angle - 1.8
			end

			if cameraState.d then
				cameraState.angle = cameraState.angle + 1.8
			end

			updatePreviewCamera()
			Wait(0)
		else
			Wait(250)
		end
	end
end)

RegisterCommand('ped', function()
	toggleEditor()
end, false)

RegisterCommand('pededitor', function()
	toggleEditor()
end, false)

RegisterCommand('+pededitor', function()
	-- legacy no-op: old saved binds may still point here (e.g. F1)
	-- keep this command registered so stale bindings do not throw unknown command errors.
	return
end, false)

RegisterCommand('-pededitor', function()
	return
end, false)

RegisterCommand('mask', function()
	toggleMask()
end, false)

RegisterCommand('+mask_toggle', function()
	toggleMask()
end, false)

RegisterCommand('-mask_toggle', function()
end, false)

RegisterKeyMapping('+mask_toggle', 'Toggle mask on or off', 'keyboard', 'Z')

RegisterNetEvent('lsrp_pededitor:open', function()
	openEditor()
end)

RegisterNetEvent('lsrp_pededitor:openCharacterCreation', function()
	openEditor({
		characterCreationMode = true,
		spawnLabel = 'Spawn Los Santos Airport'
	})
end)

RegisterNetEvent('lsrp_pededitor:close', function()
	closeEditor(false)
end)

RegisterNetEvent('lsrp_pededitor:toggle', function()
	toggleEditor()
end)

AddEventHandler('playerSpawned', function()
	restoreOutfitOnSpawn()
end)

AddEventHandler('onClientResourceStart', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	if NetworkIsPlayerActive(PlayerId()) and not IsEntityDead(PlayerPedId()) then
		restoreOutfitOnSpawn()
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	closeEditor(true)
	stopPreviewCamera()
end)
