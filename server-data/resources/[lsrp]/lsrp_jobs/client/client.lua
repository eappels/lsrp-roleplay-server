local stateBagConfig = Config.StateBag or {}

local function notify(message)
	local text = tostring(message or '')
	if text == '' then
		return
	end

	BeginTextCommandThefeedPost('STRING')
	AddTextComponentSubstringPlayerName(text)
	EndTextCommandThefeedPostTicker(false, true)
end

local function getCurrentEmploymentText()
	local playerState = LocalPlayer and LocalPlayer.state
	if not playerState then
		return 'Unemployed'
	end

	local jobLabel = tostring(playerState[stateBagConfig.jobLabel] or 'Unemployed')
	local gradeLabel = tostring(playerState[stateBagConfig.gradeLabel] or '')
	local onDuty = playerState[stateBagConfig.duty] == true

	if gradeLabel ~= '' then
		jobLabel = ('%s - %s'):format(jobLabel, gradeLabel)
	end

	if playerState[stateBagConfig.jobId] and onDuty then
		jobLabel = jobLabel .. ' (On Duty)'
	end

	return jobLabel
	end

RegisterNetEvent('lsrp_jobs:client:employmentUpdated', function(payload)
	payload = type(payload) == 'table' and payload or {}

	if payload.message then
		notify(payload.message)
		return
	end

	notify(('Employment updated: %s'):format(getCurrentEmploymentText()))
end)

RegisterNetEvent('lsrp_jobs:client:payrollReceived', function(payload)
	payload = type(payload) == 'table' and payload or {}
	local amount = math.max(0, math.floor(tonumber(payload.amount) or 0))
	local formattedAmount = tostring(payload.formattedAmount or ('LS$' .. amount))
	local label = tostring(payload.jobLabel or 'Job')
	notify(('%s payroll received: %s'):format(label, formattedAmount))
end)

RegisterNetEvent('lsrp_jobs:client:notify', function(message)
	notify(message)
end)

RegisterCommand('job', function()
	notify(getCurrentEmploymentText())
end, false)

RegisterCommand('duty', function()
	local playerState = LocalPlayer and LocalPlayer.state
	if not playerState or not playerState[stateBagConfig.jobId] then
		notify('You do not have an active job.')
		return
	end

	TriggerServerEvent('lsrp_jobs:server:setDuty', playerState[stateBagConfig.duty] ~= true)
end, false)