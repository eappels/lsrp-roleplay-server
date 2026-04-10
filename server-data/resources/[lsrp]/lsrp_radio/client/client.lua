local RESOURCE_NAME = GetCurrentResourceName()
local CALLBACK_NAMES = {
	joinChannel = RESOURCE_NAME .. ':server:joinChannel',
	leaveChannel = RESOURCE_NAME .. ':server:leaveChannel',
	getStatus = RESOURCE_NAME .. ':server:getStatus'
}
local RADIO_DISABLE_BITS = {
	doesntHaveItem = 16
}
local cachedStatus = {
	hasRadio = false,
	currentChannel = 0,
	lastChannel = 0,
	canReconnect = false
}

local Framework = {}
local lastKnownHasRadio = nil

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
	if Config.Debug == true then
		print(('[%s] %s'):format(RESOURCE_NAME, tostring(message)))
	end
end

local function voiceStarted()
	return GetResourceState('pma-voice') == 'started'
end

local function syncVoiceRadioItemState(hasRadio)
	if not voiceStarted() or type(hasRadio) ~= 'boolean' then
		return
	end

	if hasRadio == true then
		exports['pma-voice']:removeRadioDisableBit(RADIO_DISABLE_BITS.doesntHaveItem)
	else
		exports['pma-voice']:addRadioDisableBit(RADIO_DISABLE_BITS.doesntHaveItem)
	end

	lastKnownHasRadio = hasRadio
end

function Framework.notify(message, level)
	local text = trimString(message)
	if text == nil then
		return
	end

	if GetResourceState('lsrp_framework') == 'started' then
		exports['lsrp_framework']:notify(text, level)
		return
	end

	BeginTextCommandThefeedPost('STRING')
	AddTextComponentSubstringPlayerName(text)
	EndTextCommandThefeedPostTicker(false, true)
end

function Framework.triggerServerCallback(callbackName, payload, timeoutMs)
	if GetResourceState('lsrp_framework') ~= 'started' then
		return {
			ok = false,
			error = 'framework_unavailable'
		}
	end

	local ok, response = pcall(function()
		return exports['lsrp_framework']:triggerServerCallback(callbackName, type(payload) == 'table' and payload or {}, timeoutMs)
	end)

	if not ok or type(response) ~= 'table' then
		return {
			ok = false,
			error = 'framework_callback_failed'
		}
	end

	return response
end

local function getUserInput(windowTitle, defaultText, maxInputLength)
	local resourceKey = string.upper(GetCurrentResourceName())
	local textEntry = resourceKey .. '_WINDOW_TITLE'
	AddTextEntry(textEntry, trimString(windowTitle) or 'Enter:')
	DisplayOnscreenKeyboard(1, textEntry, '', defaultText or '', '', '', '', maxInputLength or 30)

	while true do
		local keyboardStatus = UpdateOnscreenKeyboard()
		if keyboardStatus == 3 or keyboardStatus == 2 then
			return nil
		end

		if keyboardStatus == 1 then
			return GetOnscreenKeyboardResult()
		end

		Wait(0)
	end
end

local function getConfiguredCommandName()
	return trimString(Config.Command) or 'radio'
end

local function getConfiguredVolumeCommandName()
	return trimString(Config.VolumeCommand) or 'radiovol'
end

local function getConfiguredDebugCommandName()
	return (trimString(Config.Command) or 'radio') .. 'debug'
end

local function isIntegerString(value)
	return type(value) == 'string' and value:match('^%d+$') ~= nil
end

local function normalizeChannel(value)
	local number = tonumber(value)
	if not number then
		return nil
	end

	number = math.floor(number)
	if number == 0 then
		return 0
	end

	local minChannel = math.max(1, math.floor(tonumber(Config.MinChannel) or 1))
	local maxChannel = math.max(minChannel, math.floor(tonumber(Config.MaxChannel) or 999))
	if number < minChannel or number > maxChannel then
		return nil
	end

	return number
end

local function fetchStatus()
	return cachedStatus, nil
end

local function showStatusNotification(status)
	status = type(status) == 'table' and status or {}
	if status.hasRadio ~= true then
		syncVoiceRadioItemState(false)
		Framework.notify('You need a handheld radio item to use radio channels.', 'warning')
		return
	end

	syncVoiceRadioItemState(true)

	if (tonumber(status.currentChannel) or 0) > 0 then
		Framework.notify(('Radio connected to channel %s.'):format(tostring(status.currentChannelLabel or status.currentChannel)), 'info')
		return
	end

	if (tonumber(status.lastChannel) or 0) > 0 then
		Framework.notify(('Radio is offline. Last tuned channel: %s.'):format(tostring(status.lastChannelLabel or status.lastChannel)), 'info')
		return
	end

	Framework.notify('Radio is offline. Use /radio or the radio item to tune a channel.', 'info')
end

local function joinChannel(channel)
	local normalizedChannel = normalizeChannel(channel)
	if not normalizedChannel or normalizedChannel <= 0 then
		Framework.notify(('Choose a radio channel between %d and %d.'):format(math.max(1, math.floor(tonumber(Config.MinChannel) or 1)), math.max(1, math.floor(tonumber(Config.MaxChannel) or 999))), 'warning')
		return false
	end

	TriggerServerEvent(RESOURCE_NAME .. ':server:joinChannel', normalizedChannel)
	return true
end

local function leaveChannel()
	TriggerServerEvent(RESOURCE_NAME .. ':server:leaveChannel')
	return true
end

local function setRadioVolume(volume)
	if not voiceStarted() then
		Framework.notify('Radio voice is unavailable because pma-voice is not started.', 'error')
		return false
	end

	local normalizedVolume = math.floor(tonumber(volume) or -1)
	if normalizedVolume < 1 or normalizedVolume > 100 then
		Framework.notify('Radio volume must be between 1 and 100.', 'warning')
		return false
	end

	exports['pma-voice']:setRadioVolume(normalizedVolume)
	Framework.notify(('Radio volume set to %d%%.'):format(normalizedVolume), 'success')
	return true
end

local function openRadioPrompt(prefilledStatus)
	local status = type(prefilledStatus) == 'table' and prefilledStatus or nil
	if not status then
		status = select(1, fetchStatus())
	end

	local defaultChannel = ''
	if type(status) == 'table' then
		local currentChannel = tonumber(status.currentChannel) or 0
		local lastChannel = tonumber(status.lastChannel) or 0
		if currentChannel > 0 then
			defaultChannel = tostring(currentChannel)
		elseif lastChannel > 0 then
			defaultChannel = tostring(lastChannel)
		end
	end

	local input = getUserInput(trimString(Config.PromptTitle) or 'Enter radio channel (0 to leave)', defaultChannel, 4)
	local trimmedInput = trimString(input)
	if not trimmedInput then
		return
	end

	if trimmedInput == '0' or trimmedInput:lower() == 'off' then
		leaveChannel()
		return
	end

	if not isIntegerString(trimmedInput) then
		Framework.notify('Enter a numeric radio channel or 0 to leave.', 'warning')
		return
	end

	joinChannel(trimmedInput)
end

local function runRadioDebug(statusOverride)
	local status = type(statusOverride) == 'table' and statusOverride or cachedStatus
	local disableRadio = LocalPlayer and LocalPlayer.state and LocalPlayer.state.disableRadio or 0
	local radioChannel = LocalPlayer and LocalPlayer.state and LocalPlayer.state.radioChannel or 0
	if not status then
		Framework.notify(('Radio debug unavailable. disableRadio=%s radioChannel=%s'):format(tostring(disableRadio), tostring(radioChannel)), 'warning')
		return
	end

	Framework.notify((
		'Radio debug: hasRadio=%s current=%s last=%s disableRadio=%s stateChannel=%s canReconnect=%s'
	):format(
		status.hasRadio == true and 'true' or 'false',
		tostring(status.currentChannel or 0),
		tostring(status.lastChannel or 0),
		tostring(disableRadio),
		tostring(radioChannel),
		status.canReconnect == true and 'true' or 'false'
	), 'info')
end

RegisterNetEvent(RESOURCE_NAME .. ':client:openRadioPrompt', function(status)
	if type(status) == 'table' then
		cachedStatus = status
		syncVoiceRadioItemState(status.hasRadio == true)
	end
	openRadioPrompt(status)
end)

RegisterNetEvent(RESOURCE_NAME .. ':client:syncStatus', function(status)
	if type(status) ~= 'table' then
		return
	end

	cachedStatus = status
	syncVoiceRadioItemState(status.hasRadio == true)
end)

RegisterNetEvent(RESOURCE_NAME .. ':client:setRadioVolume', function(volume)
	setRadioVolume(volume)
end)

RegisterNetEvent(RESOURCE_NAME .. ':client:runRadioDebug', function(status)
	if type(status) == 'table' then
		cachedStatus = status
		syncVoiceRadioItemState(status.hasRadio == true)
	end
	runRadioDebug(status)
end)

TriggerEvent('chat:addSuggestion', '/' .. getConfiguredCommandName(), 'Join, leave, or inspect handheld radio channels.', {
	{ name = 'channel|off|status|volume', help = 'Enter a channel number, off, status, or volume.' },
	{ name = 'value', help = 'Optional volume value when using the volume action.' }
})

TriggerEvent('chat:addSuggestion', '/' .. getConfiguredVolumeCommandName(), 'Set handheld radio volume.', {
	{ name = 'volume', help = 'A value between 1 and 100.' }
})

TriggerEvent('chat:addSuggestion', '/' .. getConfiguredDebugCommandName(), 'Show current handheld radio debug state.')

CreateThread(function()
	while true do
		local status = cachedStatus
		if type(status) == 'table' and status.hasRadio ~= nil then
			syncVoiceRadioItemState(status.hasRadio == true)
		elseif lastKnownHasRadio == nil then
			syncVoiceRadioItemState(false)
		end

		Wait(math.max(5000, math.floor(tonumber(Config.AccessRefreshMs) or 15000)))
	end
end)

debugPrint('Client radio commands registered.')