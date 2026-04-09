-- LSRP Phone System - Client Script
--
-- Manages the in-game phone UI, prop, animations, ringtone, and call state for
-- the local player. Communicates with the server via net events and NUI callbacks.
--
-- Key bindings:
--   F4 (default) - Toggle phone open/close (+togglePhone command)
--
-- Net events received from server:
--   lsrp_phones:client:callIncoming      - notify of an incoming call
--   lsrp_phones:client:callOutgoing      - confirm outgoing ring started
--   lsrp_phones:client:callConnected     - call was answered and voice connected
--   lsrp_phones:client:callEnded         - call was ended or failed
--   lsrp_phones:client:callStatus        - informational status message
--   lsrp_phones:client:setPhoneNumber    - server sends this player's phone number
--   lsrp_phones:client:receivePhonebook  - server sends full phonebook list
--   lsrp_phones:client:receiveParkedVehicles - list of player's parked vehicles
--
-- Local events triggered:
--   lsrp_phones:openPhone  - fired when phone opens (used by openPhone handler)
--   lsrp_phones:closePhone - fired when phone closes

local phoneOpen = false
local phoneObject = nil
local pendingIncomingCaller = nil
local playerPhoneNumber = nil
local phonebookEntries = {}
local ringtoneActive = false
local ringtoneSoundId = nil
local ringtoneMode = nil
local incomingCallAnswering = false
local phoneOpenRequestPending = false
local PHONE_APP_IDS = {
	balance = 'balance',
	messages = 'messages',
	parking = 'parking',
	taxi = 'taxi',
	calls = 'calls',
	phonebook = 'phonebook'
}

local playPhoneOpenAnim
local showPhoneUI
local stopPhoneAnim
local hidePhoneUI

local function closePhoneInterface()
	if not phoneOpen then
		return
	end

	phoneOpen = false
	stopPhoneAnim()
	hidePhoneUI()
end

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

local function triggerFrameworkCallback(callbackName, payload, timeoutMs)
	if GetResourceState('lsrp_framework') ~= 'started' then
		return {
			ok = false,
			error = 'framework_unavailable'
		}
	end

	local ok, response = pcall(function()
		return exports['lsrp_framework']:triggerServerCallback(callbackName, payload, timeoutMs)
	end)

	if not ok or type(response) ~= 'table' then
		return {
			ok = false,
			error = 'framework_callback_failed'
		}
	end

	return response
end

local function shouldUseLegacyPhoneFallback(response)
	if type(response) ~= 'table' then
		return true
	end

	if response.ok == true then
		return false
	end

	local errorCode = trimString(response.error)
	return errorCode == 'framework_unavailable'
		or errorCode == 'framework_callback_failed'
		or errorCode == 'callback_not_registered'
		or errorCode == 'phone_app_not_registered'
		or errorCode == 'timeout'
		or errorCode == 'callback_failed'
end

local function requestPhoneAppData(appId, payload, timeoutMs)
	return triggerFrameworkCallback('lsrp_framework:phone:getAppData', {
		appId = appId,
		payload = type(payload) == 'table' and payload or {}
	}, timeoutMs or 5000)
end

-- Formats an integer balance as a comma-separated LS$ string without relying on
-- lsrp_economy. Used as a fallback when the economy resource is unavailable.
local function formatFallbackBalance(balance)
	balance = math.max(0, math.floor(tonumber(balance) or 0))
	local formatted = tostring(balance)

	while true do
		local updated, replacements = formatted:gsub('^(%-?%d+)(%d%d%d)', '%1,%2')
		formatted = updated

		if replacements == 0 then
			break
		end
	end

	return 'LS$' .. formatted
end

-- Returns the current player finances as
-- (balance, formattedBalance, cash, formattedCash, economyAvailable).
-- Prefers the lsrp_economy exports when that resource is running; falls back to
-- player state bag values otherwise.
local function getBalanceSnapshot()
	local balance = math.max(0, math.floor(tonumber(LocalPlayer.state.ls_balance) or 0))
	local cash = math.max(0, math.floor(tonumber(LocalPlayer.state.ls_cash) or 0))
	local formattedBalance = formatFallbackBalance(balance)
	local formattedCash = formatFallbackBalance(cash)
	local economyAvailable = GetResourceState('lsrp_framework') == 'started'

	if economyAvailable then
		local response = triggerFrameworkCallback('lsrp_phones:getBalanceSnapshot', {}, 5000)
		if response.ok and type(response.data) == 'table' then
			balance = math.max(0, math.floor(tonumber(response.data.balance) or 0))
			cash = math.max(0, math.floor(tonumber(response.data.cash) or 0))
			formattedBalance = trimString(response.data.formattedBalance) or formatFallbackBalance(balance)
			formattedCash = trimString(response.data.formattedCash) or formatFallbackBalance(cash)
			economyAvailable = response.data.available ~= false
		end
	end

	return balance, formattedBalance, cash, formattedCash, economyAvailable
end

-- ---------------------------------------------------------------------------
-- Ringtone
-- ---------------------------------------------------------------------------

-- Immediately stops any active ringtone loop and releases the sound ID.
local function stopIncomingRingtone()
	ringtoneActive = false
	ringtoneMode = nil

	if ringtoneSoundId then
		StopSound(ringtoneSoundId)
		ReleaseSoundId(ringtoneSoundId)
		ringtoneSoundId = nil
	end
end

-- Starts the ringtone loop for the given mode ('incoming' or 'outgoing').
-- The loop plays 'Remote_Ring' every ~2.75 s and auto-stops when the
-- relevant pending-caller state is cleared. No-op if already playing the
-- same mode.
local function startPhoneRingtone(mode)
	if ringtoneActive and ringtoneMode == mode then
		return
	end

	stopIncomingRingtone()

	ringtoneActive = true
	ringtoneMode = mode

	CreateThread(function()
		while ringtoneActive do
			if ringtoneMode == 'incoming' and not pendingIncomingCaller then
				break
			end

			if ringtoneMode == 'outgoing' and pendingIncomingCaller then
				break
			end

			if ringtoneSoundId then
				StopSound(ringtoneSoundId)
				ReleaseSoundId(ringtoneSoundId)
				ringtoneSoundId = nil
			end

			ringtoneSoundId = GetSoundId()
			PlaySoundFrontend(ringtoneSoundId, 'Remote_Ring', 'Phone_SoundSet_Default', true)
			Wait(2750)
		end

		if ringtoneSoundId then
			StopSound(ringtoneSoundId)
			ReleaseSoundId(ringtoneSoundId)
			ringtoneSoundId = nil
		end

		ringtoneActive = false
		ringtoneMode = nil
	end)
end

-- ---------------------------------------------------------------------------
-- Call handling
-- ---------------------------------------------------------------------------

-- Accepts the current pending incoming call. Stops the ringtone and fires the
-- server event. Guards against duplicate calls with incomingCallAnswering flag.
-- Returns true when the accept was dispatched, false if nothing to accept.
local function acceptIncomingCall()
	if not pendingIncomingCaller or incomingCallAnswering then
		return false
	end

	incomingCallAnswering = true
	stopIncomingRingtone()
	TriggerServerEvent('lsrp_phones:server:acceptCall')
	return true
end

-- ---------------------------------------------------------------------------
-- NUI push helpers
-- ---------------------------------------------------------------------------

-- Sends the player's phone number to the NUI front-end.
local function pushPhoneNumberToNui()
	SendNUIMessage({
		action = 'setPhoneNumber',
		phoneNumber = playerPhoneNumber
	})
end

-- Sends the locally cached phonebook entries to the NUI front-end.
local function pushPhonebookToNui()
	SendNUIMessage({
		action = 'displayPhonebook',
		entries = phonebookEntries
	})
end

-- Reads the current balance snapshot and sends it to the NUI front-end.
-- No-op when the phone is not open.
local function pushBalanceToNui()
	if not phoneOpen then
		return
	end

	local balance, formattedBalance, cash, formattedCash, economyAvailable = getBalanceSnapshot()

	SendNUIMessage({
		action = 'setBalance',
		balance = balance,
		cash = cash,
		formattedBalance = formattedBalance,
		formattedCash = formattedCash,
		available = economyAvailable
	})
end

local function showPhoneNotification(message)
	BeginTextCommandThefeedPost('STRING')
	AddTextComponentSubstringPlayerName(tostring(message or ''))
	EndTextCommandThefeedPostTicker(false, false)
end

local function getStreetLabelFromCoords(coords)
	if type(coords) ~= 'table' then
		return nil
	end

	local streetHash, crossingHash = GetStreetNameAtCoord(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
	local streetName = streetHash ~= 0 and trimString(GetStreetNameFromHashKey(streetHash)) or nil
	local crossingName = crossingHash ~= 0 and trimString(GetStreetNameFromHashKey(crossingHash)) or nil

	if streetName and crossingName and crossingName ~= streetName then
		return ('%s / %s'):format(streetName, crossingName)
	end

	return streetName or crossingName
end

local function openPhoneInterface()
	if phoneOpen then
		return
	end

	phoneOpen = true
	playPhoneOpenAnim()
	showPhoneUI()
	TriggerEvent('lsrp_phones:openPhone')
end

local function requestPhoneOpen()
	if phoneOpenRequestPending then
		return
	end

	phoneOpenRequestPending = true
	CreateThread(function()
		local response = triggerFrameworkCallback('lsrp_phones:requestOpenPhone', {}, 5000)

		if shouldUseLegacyPhoneFallback(response) then
			TriggerServerEvent('lsrp_phones:server:requestOpenPhone')
			return
		end

		phoneOpenRequestPending = false

		if response.ok and type(response.data) == 'table' and response.data.phoneNumber then
			playerPhoneNumber = tostring(response.data.phoneNumber)
			pushPhoneNumberToNui()
			openPhoneInterface()
			return
		end

		playerPhoneNumber = nil
		phonebookEntries = {}
		pushPhoneNumberToNui()
		pushPhonebookToNui()
		showPhoneNotification(response.error == 'phone_required' and 'You need to buy a phone first.' or 'Your phone is not ready yet.')
		SendNUIMessage({
			action = 'messageStatus',
			message = response.error == 'phone_required' and 'You need to buy a phone first.' or 'Your phone is not ready yet.',
			isError = true
		})
	end)
end

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

local function decodeVehicleProps(rawProps)
	if type(rawProps) == 'table' then
		return rawProps
	end

	local propsText = trimString(rawProps)
	if not propsText then
		return nil
	end

	local ok, decoded = pcall(function()
		return json.decode(propsText)
	end)

	if ok and type(decoded) == 'table' then
		return decoded
	end

	return nil
end

local function prettifyVehicleLabel(label)
	local text = trimString(label)
	if not text then
		return nil
	end

	text = text:gsub('[_%-]+', ' '):gsub('%s+', ' ')

	if text == '' then
		return nil
	end

	if text == string.upper(text) then
		text = string.lower(text)
	end

	text = text:gsub('(%a)([%w]*)', function(first, rest)
		return string.upper(first) .. string.lower(rest)
	end)

	return text
end

local function resolveVehicleDisplayName(vehicle)
	if type(vehicle) ~= 'table' then
		return 'Unknown'
	end

	local props = decodeVehicleProps(vehicle.vehicle_props)
	local rawModel = trimString(vehicle.vehicle_display_name)
		or trimString(vehicle.vehicle_model)
		or trimString(props and props.modelName)
	local modelHash = tonumber(rawModel)

	if not modelHash and props and props.model ~= nil then
		modelHash = tonumber(props.model)
	end

	if not modelHash and rawModel then
		modelHash = GetHashKey(rawModel)
	end

	if modelHash and modelHash ~= 0 and IsModelInCdimage(modelHash) and IsModelAVehicle(modelHash) then
		local displayCode = trimString(GetDisplayNameFromVehicleModel(modelHash))
		if displayCode and displayCode ~= 'CARNOTFOUND' then
			local labelText = trimString(GetLabelText(displayCode))
			if labelText and labelText ~= 'NULL' then
				return labelText
			end

			local prettyCode = prettifyVehicleLabel(displayCode)
			if prettyCode then
				return prettyCode
			end
		end
	end

	local prettyRawModel = prettifyVehicleLabel(rawModel)
	if prettyRawModel then
		return prettyRawModel
	end

	local prettyPropsModel = prettifyVehicleLabel(props and props.modelName)
	if prettyPropsModel then
		return prettyPropsModel
	end

	return rawModel or 'Unknown'
end

local function normalizeParkedVehiclesForNui(vehicles)
	if type(vehicles) ~= 'table' then
		return {}
	end

	local normalizedVehicles = {}

	for index, vehicle in ipairs(vehicles) do
		if type(vehicle) == 'table' then
			local normalizedVehicle = {}

			for key, value in pairs(vehicle) do
				normalizedVehicle[key] = value
			end

			normalizedVehicle.vehicle_model = resolveVehicleDisplayName(vehicle)
			normalizedVehicles[index] = normalizedVehicle
		end
	end

	return normalizedVehicles
end

-- Load animation dictionary
local function loadAnimDict(dict)
	RequestAnimDict(dict)
	local timeout = GetGameTimer() + 5000
	
	while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
		Wait(0)
	end
	
	return HasAnimDictLoaded(dict)
end

local function cleanupPhonePropEntity(entity)
	if not entity or entity == 0 then
		return
	end

	if not DoesEntityExist(entity) then
		if phoneObject == entity then
			phoneObject = nil
		end

		return
	end

	if IsEntityAttached(entity) then
		DetachEntity(entity, true, true)
	end

	SetEntityAsMissionEntity(entity, true, true)

	if NetworkGetEntityIsNetworked(entity) then
		local timeout = GetGameTimer() + 1000

		NetworkRequestControlOfEntity(entity)

		while DoesEntityExist(entity) and not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
			Wait(0)
			NetworkRequestControlOfEntity(entity)
		end
	end

	DeleteObject(entity)

	if DoesEntityExist(entity) then
		DeleteEntity(entity)
	end

	if DoesEntityExist(entity) then
		SetEntityAsNoLongerNeeded(entity)
	end

	if phoneObject == entity then
		phoneObject = nil
	end
end

-- Remove phone prop
local function removePhoneProp()
	cleanupPhonePropEntity(phoneObject)
end

-- Create and attach phone prop
local function attachPhoneProp()
	local ped = PlayerPedId()
	local phoneModel = GetHashKey('prop_npc_phone_02')

	removePhoneProp()
	
	RequestModel(phoneModel)
	local timeout = GetGameTimer() + 5000
	
	while not HasModelLoaded(phoneModel) and GetGameTimer() < timeout do
		Wait(0)
	end
	
	if HasModelLoaded(phoneModel) then
		phoneObject = CreateObject(phoneModel, 0.0, 0.0, 0.0, true, true, false)
		SetEntityAsMissionEntity(phoneObject, true, true)
		local boneIndex = GetPedBoneIndex(ped, 28422)
		AttachEntityToEntity(phoneObject, ped, boneIndex, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
		SetModelAsNoLongerNeeded(phoneModel)
	end
end

-- Play phone open animation
playPhoneOpenAnim = function()
	local ped = PlayerPedId()
	
	if loadAnimDict('cellphone@') then
		TaskPlayAnim(ped, 'cellphone@', 'cellphone_text_in', 3.0, -8.0, -1, 50, 0, false, false, false)
		RemoveAnimDict('cellphone@')
	end
	
	attachPhoneProp()
end

-- Stop phone animation
stopPhoneAnim = function()
	local ped = PlayerPedId()
	local phoneObjectToRemove = phoneObject
	
	if loadAnimDict('cellphone@') then
		TaskPlayAnim(ped, 'cellphone@', 'cellphone_text_out', 3.0, -8.0, 1500, 50, 0, false, false, false)
		RemoveAnimDict('cellphone@')
		
		-- Wait for animation to finish before removing phone prop
		CreateThread(function()
			Wait(1500)
			cleanupPhonePropEntity(phoneObjectToRemove)
		end)
	else
		cleanupPhonePropEntity(phoneObjectToRemove)
	end
end

-- Show phone UI
showPhoneUI = function()
	SendNUIMessage({
		action = 'openPhone'
	})
	SetNuiFocus(true, true)
end

-- Hide phone UI
hidePhoneUI = function()
	SendNUIMessage({
		action = 'closePhone'
	})
	SetNuiFocus(false, false)
end

-- Toggle phone visibility
local function togglePhone()
	if pendingIncomingCaller then
		if not phoneOpen then
			openPhoneInterface()
		end

		acceptIncomingCall()
		return
	end

	if phoneOpen then
		-- Close phone
		closePhoneInterface()
		TriggerEvent('lsrp_phones:closePhone')
	else
		requestPhoneOpen()
	end
end

-- Register F4 key mapping
RegisterKeyMapping('+togglePhone', 'Toggle Phone', 'keyboard', 'F4')

RegisterCommand('+togglePhone', function()
	togglePhone()
end, false)

RegisterCommand('-togglePhone', function()
	-- Required by RegisterKeyMapping (+/- command pair).
end, false)

local FRAMEWORK_NUI_EVENTS = {
	closePhone = 'lsrp_phones:frameworkNui:closePhone',
	getBalance = 'lsrp_phones:frameworkNui:getBalance',
	getPhonebook = 'lsrp_phones:frameworkNui:getPhonebook',
	getTaxiAppState = 'lsrp_phones:frameworkNui:getTaxiAppState',
	getMessageConversations = 'lsrp_phones:frameworkNui:getMessageConversations',
	getMessageThread = 'lsrp_phones:frameworkNui:getMessageThread'
}

-- ---------------------------------------------------------------------------
-- NUI callbacks (called from the HTML/JS front-end via fetch POST)
-- ---------------------------------------------------------------------------

-- NUI callback from phone close button
RegisterNUICallback('closePhone', function(_, cb)
	closePhoneInterface()
	TriggerEvent('lsrp_phones:closePhone')
	cb({ ok = true })
end)

-- NUI callback to get parked vehicles
RegisterNUICallback('getParkedVehicles', function(data, cb)
	local response = requestPhoneAppData(PHONE_APP_IDS.parking, {}, 5000)
	if shouldUseLegacyPhoneFallback(response) then
		print('[lsrp_phones] NUI requested parked vehicles')
		TriggerServerEvent('lsrp_phones:server:requestParkedVehicles')
		cb('ok')
		return
	end

	if response.ok and type(response.data) == 'table' then
		SendNUIMessage({
			action = 'displayVehicles',
			vehicles = normalizeParkedVehiclesForNui(type(response.data.vehicles) == 'table' and response.data.vehicles or {})
		})
	end

	cb(response)
end)

RegisterNUICallback('setParkingWaypoint', function(data, cb)
	local zoneName = nil

	if type(data) == 'table' and data.zoneName ~= nil then
		zoneName = tostring(data.zoneName):gsub('^%s+', ''):gsub('%s+$', '')
	end

	if not zoneName or zoneName == '' then
		cb({ ok = false, error = 'invalid_zone' })
		return
	end

	if GetResourceState('lsrp_vehicleparking') ~= 'started' then
		cb({ ok = false, error = 'parking_unavailable' })
		return
	end

	TriggerEvent('lsrp_vehicleparking:client:setWaypointToZone', zoneName)
	cb({ ok = true })
end)

exports['lsrp_framework']:registerNuiCallback('getBalance', FRAMEWORK_NUI_EVENTS.getBalance)

exports['lsrp_framework']:registerNuiCallback('getPhonebook', FRAMEWORK_NUI_EVENTS.getPhonebook)

exports['lsrp_framework']:registerNuiCallback('getTaxiAppState', FRAMEWORK_NUI_EVENTS.getTaxiAppState)

RegisterNUICallback('bookTaxiRide', function(data, cb)
	local playerPed = PlayerPedId()
	if playerPed == 0 or not DoesEntityExist(playerPed) then
		cb({ ok = false, error = 'player_unavailable' })
		return
	end

	local waypointBlip = GetFirstBlipInfoId(8)
	if not waypointBlip or waypointBlip == 0 or not DoesBlipExist(waypointBlip) then
		cb({ ok = false, error = 'missing_waypoint' })
		return
	end

	local pickupCoords = GetEntityCoords(playerPed)
	local destinationCoords = GetBlipInfoIdCoord(waypointBlip)
	if not destinationCoords then
		cb({ ok = false, error = 'missing_waypoint' })
		return
	end

	TriggerServerEvent('lsrp_phones:server:bookTaxiRide', {
		pickupCoords = {
			x = pickupCoords.x,
			y = pickupCoords.y,
			z = pickupCoords.z
		},
		pickupLabel = getStreetLabelFromCoords({ x = pickupCoords.x, y = pickupCoords.y, z = pickupCoords.z }) or 'Current location',
		destinationCoords = {
			x = destinationCoords.x,
			y = destinationCoords.y,
			z = destinationCoords.z
		},
		destinationLabel = trimString(data and data.destinationLabel) or getStreetLabelFromCoords({ x = destinationCoords.x, y = destinationCoords.y, z = destinationCoords.z }) or 'Waypoint',
		scheduledFor = trimString(data and data.scheduledFor) or 'ASAP',
		notes = trimString(data and data.notes)
	})

	cb({ ok = true })
end)

RegisterNUICallback('cancelTaxiRide', function(_, cb)
	TriggerServerEvent('lsrp_phones:server:cancelTaxiRide')
	cb({ ok = true })
end)

RegisterNUICallback('claimTaxiRide', function(data, cb)
	local rideId = tonumber(data and data.rideId)
	if not rideId or rideId <= 0 then
		cb({ ok = false, error = 'invalid_ride' })
		return
	end

	TriggerServerEvent('lsrp_phones:server:claimTaxiRide', math.floor(rideId))
	cb({ ok = true })
end)

RegisterNUICallback('releaseTaxiRide', function(_, cb)
	TriggerServerEvent('lsrp_phones:server:releaseTaxiRide')
	cb({ ok = true })
end)

exports['lsrp_framework']:registerNuiCallback('getMessageConversations', FRAMEWORK_NUI_EVENTS.getMessageConversations)

exports['lsrp_framework']:registerNuiCallback('getMessageThread', FRAMEWORK_NUI_EVENTS.getMessageThread)

AddEventHandler(FRAMEWORK_NUI_EVENTS.getBalance, function(data, meta, respond)
	local response = requestPhoneAppData(PHONE_APP_IDS.balance, {}, 5000)
	if shouldUseLegacyPhoneFallback(response) then
		pushBalanceToNui()
		respond({ ok = true, data = { legacy = true } })
		return
	end

	if response.ok and type(response.data) == 'table' then
		setBalance(
			response.data.balance,
			response.data.formattedBalance,
			response.data.cash,
			response.data.formattedCash,
			response.data.available
		)
	end

	respond(response)
end)

AddEventHandler(FRAMEWORK_NUI_EVENTS.getPhonebook, function(data, meta, respond)
	local response = requestPhoneAppData(PHONE_APP_IDS.phonebook, {}, 5000)
	if shouldUseLegacyPhoneFallback(response) then
		TriggerServerEvent('lsrp_phones:server:requestPhonebook')
		respond({ ok = true, data = { legacy = true } })
		return
	end

	if response.ok and type(response.data) == 'table' then
		phonebookEntries = type(response.data.entries) == 'table' and response.data.entries or {}
		if response.data.phoneNumber then
			playerPhoneNumber = tostring(response.data.phoneNumber)
			pushPhoneNumberToNui()
		end
		pushPhonebookToNui()
	end

	respond(response)
end)

AddEventHandler(FRAMEWORK_NUI_EVENTS.getTaxiAppState, function(data, meta, respond)
	local response = requestPhoneAppData(PHONE_APP_IDS.taxi, {}, 5000)
	if shouldUseLegacyPhoneFallback(response) then
		TriggerServerEvent('lsrp_phones:server:requestTaxiAppState')
		respond({ ok = true, data = { legacy = true } })
		return
	end

	if response.ok and type(response.data) == 'table' then
		SendNUIMessage({
			action = 'displayTaxiAppState',
			state = type(response.data.state) == 'table' and response.data.state or {}
		})

		if response.data.message then
			SendNUIMessage({
				action = 'taxiAppStatus',
				message = response.data.message,
				isError = response.data.isError == true
			})
		end
	end

	respond(response)
end)

AddEventHandler(FRAMEWORK_NUI_EVENTS.getMessageConversations, function(data, meta, respond)
	local response = requestPhoneAppData(PHONE_APP_IDS.messages, {}, 5000)
	if shouldUseLegacyPhoneFallback(response) then
		TriggerServerEvent('lsrp_phones:server:requestMessageConversations')
		respond({ ok = true, data = { legacy = true } })
		return
	end

	if response.ok and type(response.data) == 'table' then
		SendNUIMessage({
			action = 'displayMessageConversations',
			conversations = type(response.data.conversations) == 'table' and response.data.conversations or {},
			unreadTotal = tonumber(response.data.unreadTotal) or 0
		})
	end

	respond(response)
end)

AddEventHandler(FRAMEWORK_NUI_EVENTS.getMessageThread, function(data, meta, respond)
	local phoneNumber = tostring((data and data.phoneNumber) or '')
	phoneNumber = phoneNumber:gsub('^%s+', ''):gsub('%s+$', '')

	if phoneNumber == '' then
		respond({ ok = false, error = 'invalid_target' })
		return
	end

	local response = triggerFrameworkCallback('lsrp_phones:getMessageThread', {
		phoneNumber = phoneNumber
	}, 5000)

	if shouldUseLegacyPhoneFallback(response) then
		TriggerServerEvent('lsrp_phones:server:requestMessageThread', phoneNumber)
		respond({ ok = true, data = { legacy = true } })
		return
	end

	if response.ok and type(response.data) == 'table' then
		SendNUIMessage({
			action = 'displayMessageThread',
			thread = response.data.thread
		})

		local conversationsResponse = triggerFrameworkCallback('lsrp_phones:getMessageConversations', {}, 5000)
		if conversationsResponse.ok and type(conversationsResponse.data) == 'table' then
			SendNUIMessage({
				action = 'displayMessageConversations',
				conversations = type(conversationsResponse.data.conversations) == 'table' and conversationsResponse.data.conversations or {},
				unreadTotal = tonumber(conversationsResponse.data.unreadTotal) or 0
			})
		end
	end

	respond(response)
end)

RegisterNUICallback('sendMessage', function(data, cb)
	local phoneNumber = tostring((data and data.phoneNumber) or '')
	local body = tostring((data and data.body) or '')

	phoneNumber = phoneNumber:gsub('^%s+', ''):gsub('%s+$', '')
	body = body:gsub('^%s+', ''):gsub('%s+$', '')

	if phoneNumber == '' then
		cb({ ok = false, error = 'invalid_target' })
		return
	end

	if body == '' then
		cb({ ok = false, error = 'empty_message' })
		return
	end

	TriggerServerEvent('lsrp_phones:server:sendMessage', phoneNumber, body)
	cb({ ok = true })
end)

-- NUI callback to start a player-to-player phone call
RegisterNUICallback('startCall', function(data, cb)
	local phoneNumber = tostring((data and data.phoneNumber) or '')
	phoneNumber = phoneNumber:gsub('^%s+', ''):gsub('%s+$', '')

	if phoneNumber == '' then
		cb({ ok = false, error = 'invalid_target' })
		return
	end

	TriggerServerEvent('lsrp_phones:server:startCall', phoneNumber)
	cb({ ok = true })
end)

RegisterNUICallback('acceptCall', function(_, cb)
	if acceptIncomingCall() then
		cb({ ok = true })
		return
	end

	cb({ ok = false, error = 'no_incoming_call' })
end)

RegisterNUICallback('declineCall', function(_, cb)
	if pendingIncomingCaller then
		incomingCallAnswering = false
		stopIncomingRingtone()
		TriggerServerEvent('lsrp_phones:server:declineCall')
		cb({ ok = true })
		return
	end

	cb({ ok = false, error = 'no_incoming_call' })
end)

RegisterNUICallback('endCall', function(_, cb)
	TriggerServerEvent('lsrp_phones:server:endCall')
	cb({ ok = true })
end)

-- ---------------------------------------------------------------------------
-- Net event handlers (triggered by the server)
-- ---------------------------------------------------------------------------

-- Receive parked vehicles from server
RegisterNetEvent('lsrp_phones:client:receiveParkedVehicles')
AddEventHandler('lsrp_phones:client:receiveParkedVehicles', function(vehicles)
	print('[lsrp_phones] Received ' .. #vehicles .. ' parked vehicles')
	SendNUIMessage({
		action = 'displayVehicles',
		vehicles = normalizeParkedVehiclesForNui(vehicles)
	})
end)

RegisterNetEvent('lsrp_phones:client:receivePhonebook')
AddEventHandler('lsrp_phones:client:receivePhonebook', function(entries)
	phonebookEntries = type(entries) == 'table' and entries or {}
	pushPhonebookToNui()
end)

RegisterNetEvent('lsrp_phones:client:openPhoneAuthorized')
AddEventHandler('lsrp_phones:client:openPhoneAuthorized', function(phoneNumber)
	phoneOpenRequestPending = false
	playerPhoneNumber = phoneNumber and tostring(phoneNumber) or nil
	pushPhoneNumberToNui()
	openPhoneInterface()
end)

RegisterNetEvent('lsrp_phones:client:openPhoneDenied')
AddEventHandler('lsrp_phones:client:openPhoneDenied', function(message)
	phoneOpenRequestPending = false
	playerPhoneNumber = nil
	phonebookEntries = {}
	pushPhoneNumberToNui()
	pushPhonebookToNui()
	showPhoneNotification(message or 'You need to buy a phone first.')
	SendNUIMessage({
		action = 'messageStatus',
		message = message or 'You need to buy a phone first.',
		isError = true
	})
end)

RegisterNetEvent('lsrp_phones:client:receiveMessageConversations')
AddEventHandler('lsrp_phones:client:receiveMessageConversations', function(conversations, unreadTotal)
	SendNUIMessage({
		action = 'displayMessageConversations',
		conversations = type(conversations) == 'table' and conversations or {},
		unreadTotal = tonumber(unreadTotal) or 0
	})
end)

RegisterNetEvent('lsrp_phones:client:taxiAppState')
AddEventHandler('lsrp_phones:client:taxiAppState', function(state)
	SendNUIMessage({
		action = 'displayTaxiAppState',
		state = type(state) == 'table' and state or {}
	})
end)

RegisterNetEvent('lsrp_phones:client:taxiAppStatus')
AddEventHandler('lsrp_phones:client:taxiAppStatus', function(message, isError)
	SendNUIMessage({
		action = 'taxiAppStatus',
		message = message or '',
		isError = isError == true
	})
end)

RegisterNetEvent('lsrp_phones:client:receiveMessageThread')
AddEventHandler('lsrp_phones:client:receiveMessageThread', function(thread)
	SendNUIMessage({
		action = 'displayMessageThread',
		thread = thread
	})
end)

RegisterNetEvent('lsrp_phones:client:messageIncoming')
AddEventHandler('lsrp_phones:client:messageIncoming', function(fromNumber, preview)
	local senderNumber = tostring(fromNumber or 'Unknown')
	local messagePreview = tostring(preview or 'New message received.')

	if not phoneOpen then
		showPhoneNotification(('Text from %s: %s'):format(senderNumber, messagePreview))
	end

	SendNUIMessage({
		action = 'messageIncoming',
		phoneNumber = senderNumber,
		preview = messagePreview
	})
end)

RegisterNetEvent('lsrp_phones:client:messageStatus')
AddEventHandler('lsrp_phones:client:messageStatus', function(message, isError)
	SendNUIMessage({
		action = 'messageStatus',
		message = message or '',
		isError = isError == true
	})
end)

RegisterNetEvent('lsrp_phones:client:callIncoming')
AddEventHandler('lsrp_phones:client:callIncoming', function(fromNumber)
	pendingIncomingCaller = tostring(fromNumber)
	incomingCallAnswering = false
	startPhoneRingtone('incoming')

	SendNUIMessage({
		action = 'callIncoming',
		fromNumber = pendingIncomingCaller
	})
end)

RegisterNetEvent('lsrp_phones:client:callOutgoing')
AddEventHandler('lsrp_phones:client:callOutgoing', function(targetNumber)
	if not pendingIncomingCaller then
		startPhoneRingtone('outgoing')
	end

	SendNUIMessage({
		action = 'callOutgoing',
		targetNumber = tostring(targetNumber)
	})
end)

RegisterNetEvent('lsrp_phones:client:callConnected')
AddEventHandler('lsrp_phones:client:callConnected', function(otherNumber)
	pendingIncomingCaller = nil
	incomingCallAnswering = false
	stopIncomingRingtone()

	SendNUIMessage({
		action = 'callConnected',
		otherNumber = tostring(otherNumber)
	})
end)

RegisterNetEvent('lsrp_phones:client:callEnded')
AddEventHandler('lsrp_phones:client:callEnded', function(reason)
	pendingIncomingCaller = nil
	incomingCallAnswering = false
	stopIncomingRingtone()

	SendNUIMessage({
		action = 'callEnded',
		reason = reason or 'Call ended.'
	})
end)

RegisterNetEvent('lsrp_phones:client:callStatus')
AddEventHandler('lsrp_phones:client:callStatus', function(message)
	SendNUIMessage({
		action = 'callStatus',
		message = message
	})
end)

RegisterNetEvent('lsrp_phones:client:setPhoneNumber')
AddEventHandler('lsrp_phones:client:setPhoneNumber', function(phoneNumber)
	if phoneNumber then
		playerPhoneNumber = tostring(phoneNumber)
	else
		playerPhoneNumber = nil
	end

	pushPhoneNumberToNui()
end)

RegisterNetEvent('lsrp_economy:client:balanceUpdated')
AddEventHandler('lsrp_economy:client:balanceUpdated', function()
	pushBalanceToNui()
end)

RegisterNetEvent('lsrp_economy:client:cashUpdated')
AddEventHandler('lsrp_economy:client:cashUpdated', function()
	pushBalanceToNui()
end)

-- Phone open event
AddEventHandler('lsrp_phones:openPhone', function()
	pushBalanceToNui()
	local phonebookResponse = triggerFrameworkCallback('lsrp_phones:getPhonebook', {}, 5000)
	if shouldUseLegacyPhoneFallback(phonebookResponse) then
		TriggerServerEvent('lsrp_phones:server:requestPhoneNumber')
		TriggerServerEvent('lsrp_phones:server:requestPhonebook')
	else
		if phonebookResponse.ok and type(phonebookResponse.data) == 'table' then
			phonebookEntries = type(phonebookResponse.data.entries) == 'table' and phonebookResponse.data.entries or {}
			if phonebookResponse.data.phoneNumber then
				playerPhoneNumber = tostring(phonebookResponse.data.phoneNumber)
			end
		end
	end

	local messageResponse = triggerFrameworkCallback('lsrp_phones:getMessageConversations', {}, 5000)
	if shouldUseLegacyPhoneFallback(messageResponse) then
		TriggerServerEvent('lsrp_phones:server:requestMessageConversations')
	elseif messageResponse.ok and type(messageResponse.data) == 'table' then
		SendNUIMessage({
			action = 'displayMessageConversations',
			conversations = type(messageResponse.data.conversations) == 'table' and messageResponse.data.conversations or {},
			unreadTotal = tonumber(messageResponse.data.unreadTotal) or 0
		})
	end

	local taxiResponse = triggerFrameworkCallback('lsrp_phones:getTaxiAppState', {}, 5000)
	if shouldUseLegacyPhoneFallback(taxiResponse) then
		TriggerServerEvent('lsrp_phones:server:requestTaxiAppState')
	elseif taxiResponse.ok and type(taxiResponse.data) == 'table' then
		SendNUIMessage({
			action = 'displayTaxiAppState',
			state = type(taxiResponse.data.state) == 'table' and taxiResponse.data.state or {}
		})
	end

	pushPhoneNumberToNui()
	pushPhonebookToNui()
end)

-- Phone close event
AddEventHandler('lsrp_phones:closePhone', function()
	closePhoneInterface()
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	stopIncomingRingtone()
	removePhoneProp()
	SetNuiFocus(false, false)
end)
