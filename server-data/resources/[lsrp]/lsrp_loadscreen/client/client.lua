-- LSRP Loadscreen - Client Script
--
-- Keeps the loading screen and busy spinner suppressed until the server
-- explicitly sends the 'lsrp_loadscreen:shutdown' event.  A persistent guard
-- thread keeps clearing the spinner every 250 ms while the session is active,
-- covering edge cases where GTA re-shows it after the initial clear.
--
-- Net events received:
--   lsrp_loadscreen:shutdown  - shuts down the NUI loadscreen and begins the
--                               retry loop that clears residual spinners.

local shutdownStarted = false
local shutdownRetryDurationMs = 10000
local shutdownRetryIntervalMs = 0
local spinnerGuardDeadline = 0
local spinnerGuardThreadActive = false
local persistentSpinnerGuardIntervalMs = 250
local prejoinVisible = false
local prejoinSpawnPoints = {
	{ x = -1037.7, y = -2737.3, z = 20.17, heading = 0.0, label = 'Los Santos International' },
	{ x = 215.76, y = -810.12, z = 30.73, heading = 180.0, label = 'Legion Square' },
	{ x = 340.0, y = -579.0, z = 28.8, heading = 90.0, label = 'Pillbox Hill' }
}

local function hideLoadingIndicators()
	if type(BusyspinnerOff) == 'function' then
		BusyspinnerOff()
	end

	if type(RemoveLoadingPrompt) == 'function' then
		RemoveLoadingPrompt()
	end
end

-- Calls all three known loading-screen dismiss natives for robustness.
local function clearLoadingScreenNow()
	if prejoinVisible then
		return
	end

	ShutdownLoadingScreen()
	hideLoadingIndicators()

	if type(ShutdownLoadingScreenNui) == 'function' then
		ShutdownLoadingScreenNui()
	end
end

-- Runs clearLoadingScreenNow on a tight loop for durationMs milliseconds.
-- Multiple callers are coalesced into a single thread via spinnerGuardDeadline.
local function keepClearingLoadingScreen(durationMs, intervalMs)
	local timeoutAt = GetGameTimer() + (durationMs or 3000)
	local interval = intervalMs or 100

	if timeoutAt > spinnerGuardDeadline then
		spinnerGuardDeadline = timeoutAt
	end

	if spinnerGuardThreadActive then
		return
	end

	spinnerGuardThreadActive = true

	CreateThread(function()
		while GetGameTimer() < spinnerGuardDeadline do
			clearLoadingScreenNow()
			Wait(interval)
		end

		spinnerGuardThreadActive = false
	end)
end

-- Triggers the NUI progress bar to 100% and starts the spinner-clearing loop.
-- Idempotent: subsequent calls are no-ops after the first.
local function shutdownLoadscreenNow()
	if shutdownStarted then
		return
	end

	prejoinVisible = false
	shutdownStarted = true
	hideLoadingIndicators()

	if type(SendNUIMessage) == 'function' then
		SendNUIMessage({
			eventName = 'lsrpProgress',
			progress = 100,
			status = 'Joining server'
		})
	end

	CreateThread(function()
		local timeoutAt = GetGameTimer() + shutdownRetryDurationMs

		while GetGameTimer() < timeoutAt do
			clearLoadingScreenNow()

			Wait(shutdownRetryIntervalMs)
		end
	end)
end

RegisterNetEvent('lsrp_loadscreen:shutdown')
AddEventHandler('lsrp_loadscreen:shutdown', shutdownLoadscreenNow)

local function showPrejoinUi()
	shutdownStarted = false
	prejoinVisible = true

	if type(SendNUIMessage) == 'function' then
		SendNUIMessage({
			eventName = 'prejoin_show',
			spawnPoints = prejoinSpawnPoints
		})
	end
end

RegisterNetEvent('lsrp_loadscreen:showPrejoin')
AddEventHandler('lsrp_loadscreen:showPrejoin', showPrejoinUi)

-- NUI callbacks for prejoin (/prejoinRegister, /prejoinLogin, /prejoinSpawnSelect)
RegisterNUICallback = RegisterNUICallback or function() end

RegisterNUICallback('prejoinRegister', function(data, cb)
	local email = tostring(data.email or '')
	local password = tostring(data.password or '')

	-- forward to server and await response via event
	local requestId = math.random(100000, 999999)
	local responded = false

	local function onResult(success, reason)
		if responded then return end
		responded = true
		cb({ success = success == true, reason = reason })
	end

	RegisterNetEvent('lsrp_prejoin:registerResult' .. requestId)
	AddEventHandler('lsrp_prejoin:registerResult' .. requestId, function(ok, reason)
		onResult(ok, reason)
	end)

	-- ask server to register; server will emit back to this source resource event name with matching id
	TriggerServerEvent('lsrp_prejoin:register', requestId, { email = email, password = password })
end)

RegisterNUICallback('prejoinLogin', function(data, cb)
	local email = tostring(data.email or '')
	local password = tostring(data.password or '')
	local requestId = math.random(100000, 999999)
	local responded = false

	local function onResult(success, reason)
		if responded then return end
		responded = true
		cb({ success = success == true, reason = reason })
	end

	RegisterNetEvent('lsrp_prejoin:loginResult' .. requestId)
	AddEventHandler('lsrp_prejoin:loginResult' .. requestId, function(ok, reason)
		onResult(ok, reason)
	end)

	TriggerServerEvent('lsrp_prejoin:login', requestId, { email = email, password = password })
end)

-- spawn selection from NUI: call local spawn export on client
RegisterNUICallback('prejoinSpawnSelect', function(data, cb)
	local idx = tonumber(data.spawnIndex) or 0
	local spawn = prejoinSpawnPoints[idx + 1]
	if not spawn then
		cb({ success = false, reason = 'Invalid spawn' })
		return
	end

	prejoinVisible = false

	-- call exported spawn on this resource or the spawner resource
	if exports and exports.lsrp_spawner and exports.lsrp_spawner.spawnPlayerDirect then
		exports.lsrp_spawner.spawnPlayerDirect(spawn)
		cb({ success = true })
		return
	end

	-- fallback: trigger server request spawn (older flow)
	TriggerServerEvent('lsrp_spawner:requestSpawn')
	cb({ success = true })
end)

CreateThread(function()
	while not NetworkIsSessionStarted() do
		if not prejoinVisible then
			clearLoadingScreenNow()
		end
		Wait(0)
	end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	keepClearingLoadingScreen(60000, 0)
end)

CreateThread(function()
	while true do
		hideLoadingIndicators()

		if NetworkIsSessionStarted() then
			if not prejoinVisible and shutdownStarted then
				ShutdownLoadingScreen()

				if type(ShutdownLoadingScreenNui) == 'function' then
					ShutdownLoadingScreenNui()
				end
			end

			Wait(persistentSpinnerGuardIntervalMs)
		else
			if not prejoinVisible then
				clearLoadingScreenNow()
			end
			Wait(0)
		end
	end
end)
