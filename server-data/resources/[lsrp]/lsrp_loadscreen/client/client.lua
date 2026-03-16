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

CreateThread(function()
	while not NetworkIsSessionStarted() do
		clearLoadingScreenNow()
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
			ShutdownLoadingScreen()

			if type(ShutdownLoadingScreenNui) == 'function' then
				ShutdownLoadingScreenNui()
			end

			Wait(persistentSpinnerGuardIntervalMs)
		else
			clearLoadingScreenNow()
			Wait(0)
		end
	end
end)
