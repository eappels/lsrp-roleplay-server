local RESOURCE_NAME = GetCurrentResourceName()

local NEED_ORDER = {
	'hunger',
	'thirst'
}

local NEED_DEFINITIONS = {
	hunger = {
		key = 'hunger',
		label = 'hunger',
		configKey = 'Hunger',
		stateKey = 'lsrp_hunger',
		collapseStateKey = 'lsrp_hunger_collapsed',
		clientUpdateEvent = 'lsrp_hunger:client:update',
		clientNotifyEvent = 'lsrp_hunger:client:notify',
		clientReviveEvent = 'lsrp_hunger:client:revive',
		clientDamageEvent = 'lsrp_hunger:client:applyDamage',
		serverRequestSyncEvent = 'lsrp_hunger:server:requestSync',
		getCurrentExport = 'getCurrentHunger',
		getMaxExport = 'getMaxHunger',
		maxField = 'maxHunger',
		collapseMessage = 'You collapse from starvation and cannot move.'
	},
	thirst = {
		key = 'thirst',
		label = 'thirst',
		configKey = 'Thirst',
		stateKey = 'lsrp_thirst',
		collapseStateKey = 'lsrp_thirst_collapsed',
		clientUpdateEvent = 'lsrp_thirst:client:update',
		clientNotifyEvent = 'lsrp_thirst:client:notify',
		clientReviveEvent = 'lsrp_thirst:client:revive',
		clientDamageEvent = 'lsrp_thirst:client:applyDamage',
		serverRequestSyncEvent = 'lsrp_thirst:server:requestSync',
		getCurrentExport = 'getCurrentThirst',
		getMaxExport = 'getMaxThirst',
		maxField = 'maxThirst',
		collapseMessage = 'You collapse from dehydration and cannot move.'
	}
}

local currentValues = {
	hunger = nil,
	thirst = nil
}

local collapseActiveByNeed = {
	hunger = false,
	thirst = false
}

local collapseStartedAtByNeed = {
	hunger = 0,
	thirst = 0
}

local knockoutPoseAppliedByNeed = {
	hunger = false,
	thirst = false
}

local KNOCKOUT_ANIM_DICT = 'dead'
local KNOCKOUT_ANIM_NAME = 'dead_a'
local COLLAPSE_RAGDOLL_MS = 1200
local COLLAPSE_POSE_DELAY_MS = 1300

local BLOCKED_CONTROLS = {
	21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 44, 45, 75, 140, 141, 142, 143
}

local function getNeedConfig(definition)
	return (Config and Config[definition.configKey]) or {}
end

local function getMaxValue(definition)
	return math.max(1, math.floor(tonumber(getNeedConfig(definition)[definition.maxField]) or 100))
end

local function normalizeValue(definition, value)
	local normalizedValue = math.floor(tonumber(value) or getMaxValue(definition))
	if normalizedValue < 0 then
		return 0
	end

	local maxValue = getMaxValue(definition)
	if normalizedValue > maxValue then
		return maxValue
	end

	return normalizedValue
end

local function getPercentValue(definition, value)
	local maxValue = getMaxValue(definition)
	if maxValue <= 0 then
		maxValue = 100
	end

	value = normalizeValue(definition, value)
	return math.floor(((value / maxValue) * 100.0) + 0.5)
end

local function showNotification(message)
	local text = tostring(message or '')
	if text == '' then
		return
	end

	if GetResourceState('lsrp_framework') == 'started' then
		exports['lsrp_framework']:notify(text, 'warning')
		return
	end

	BeginTextCommandThefeedPost('STRING')
	AddTextComponentSubstringPlayerName(text)
	EndTextCommandThefeedPostTicker(false, false)
	print(('[%s] %s'):format(RESOURCE_NAME, text))
end

local function clearCollapseState(definition)
	collapseActiveByNeed[definition.key] = false
	collapseStartedAtByNeed[definition.key] = 0
	knockoutPoseAppliedByNeed[definition.key] = false
	LocalPlayer.state:set(definition.collapseStateKey, false, true)

	local ped = PlayerPedId()
	if ped ~= 0 and DoesEntityExist(ped) and not IsEntityDead(ped) then
		FreezeEntityPosition(ped, false)
		SetPedCanRagdoll(ped, true)
		ClearPedTasks(ped)
	end
end

local function ensureAnimDictLoaded(animDict)
	if HasAnimDictLoaded(animDict) then
		return true
	end

	RequestAnimDict(animDict)
	local timeoutAt = GetGameTimer() + 3000
	while not HasAnimDictLoaded(animDict) do
		if GetGameTimer() >= timeoutAt then
			return false
		end
		Wait(0)
	end

	return true
end

local function applyCollapseRagdoll(ped)
	ClearPedTasksImmediately(ped)
	SetPedToRagdoll(ped, COLLAPSE_RAGDOLL_MS, COLLAPSE_RAGDOLL_MS, 0, false, false, false)
end

local function applyKnockedOutPose(ped)
	if not ensureAnimDictLoaded(KNOCKOUT_ANIM_DICT) then
		return
	end

	ClearPedTasksImmediately(ped)
	FreezeEntityPosition(ped, true)
	SetPedCanRagdoll(ped, false)
	TaskPlayAnim(ped, KNOCKOUT_ANIM_DICT, KNOCKOUT_ANIM_NAME, 8.0, -8.0, -1, 1, 0.0, false, false, false)
	SetPedKeepTask(ped, true)
end

local function disableCollapseControls()
	for _, controlId in ipairs(BLOCKED_CONTROLS) do
		DisableControlAction(0, controlId, true)
	end
end

local function shouldSuspendCollapsePose(ped)
	local playerState = LocalPlayer and LocalPlayer.state or nil
	if playerState and playerState.lsrp_ems_in_treatment == true then
		return true
	end

	return ped ~= 0 and DoesEntityExist(ped) and IsPedInAnyVehicle(ped, false)
end

for _, needName in ipairs(NEED_ORDER) do
	local definition = NEED_DEFINITIONS[needName]
	RegisterNetEvent(definition.clientUpdateEvent, function(value)
		currentValues[definition.key] = normalizeValue(definition, value)
		TriggerEvent('lsrp_hud:client:setNeedPercent', definition.key, getPercentValue(definition, currentValues[definition.key]))
	end)

	RegisterNetEvent(definition.clientNotifyEvent, function(message)
		showNotification(message)
	end)

	RegisterNetEvent(definition.clientReviveEvent, function()
		clearCollapseState(definition)
	end)

	RegisterNetEvent(definition.clientDamageEvent, function(amount)
		local damage = math.max(0, math.floor(tonumber(amount) or 0))
		if damage <= 0 then
			return
		end

		local ped = PlayerPedId()
		if ped == 0 or not DoesEntityExist(ped) then
			return
		end

		local currentHealth = GetEntityHealth(ped)
		if currentHealth <= 0 then
			return
		end

		SetEntityHealth(ped, math.max(0, currentHealth - damage))
	end)

	local currentDefinition = definition
	exports(definition.getCurrentExport, function()
		if currentValues[currentDefinition.key] ~= nil then
			return currentValues[currentDefinition.key]
		end

		return normalizeValue(currentDefinition, LocalPlayer and LocalPlayer.state and LocalPlayer.state[currentDefinition.stateKey])
	end)

	exports(definition.getMaxExport, function()
		return getMaxValue(currentDefinition)
	end)
end

AddEventHandler('onClientResourceStart', function(resourceName)
	if resourceName ~= RESOURCE_NAME then
		return
	end

	for _, needName in ipairs(NEED_ORDER) do
		TriggerServerEvent(NEED_DEFINITIONS[needName].serverRequestSyncEvent)
	end
end)

AddEventHandler('playerSpawned', function()
	for _, needName in ipairs(NEED_ORDER) do
		local definition = NEED_DEFINITIONS[needName]
		clearCollapseState(definition)
		TriggerServerEvent(definition.serverRequestSyncEvent)
	end
end)

CreateThread(function()
	while true do
		Wait(0)

		local ped = PlayerPedId()
		if ped == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) then
			goto continue
		end

		local anyCollapseActive = false
		for _, needName in ipairs(NEED_ORDER) do
			local definition = NEED_DEFINITIONS[needName]
			local currentValue = currentValues[definition.key]
			if currentValue ~= nil then
				if currentValue <= 0 and not collapseActiveByNeed[definition.key] then
					collapseActiveByNeed[definition.key] = true
					collapseStartedAtByNeed[definition.key] = GetGameTimer()
					knockoutPoseAppliedByNeed[definition.key] = false
					LocalPlayer.state:set(definition.collapseStateKey, true, true)
					showNotification(definition.collapseMessage)
					FreezeEntityPosition(ped, false)
					SetPedCanRagdoll(ped, true)
					applyCollapseRagdoll(ped)
				end

				if collapseActiveByNeed[definition.key] then
					anyCollapseActive = true
					if shouldSuspendCollapsePose(ped) then
						FreezeEntityPosition(ped, false)
						SetPedCanRagdoll(ped, true)
					else
						if not knockoutPoseAppliedByNeed[definition.key]
							and collapseStartedAtByNeed[definition.key] > 0
							and (GetGameTimer() - collapseStartedAtByNeed[definition.key]) >= COLLAPSE_POSE_DELAY_MS then
							knockoutPoseAppliedByNeed[definition.key] = true
							applyKnockedOutPose(ped)
						elseif knockoutPoseAppliedByNeed[definition.key]
							and not IsEntityPlayingAnim(ped, KNOCKOUT_ANIM_DICT, KNOCKOUT_ANIM_NAME, 3) then
							applyKnockedOutPose(ped)
						end
					end
				end
			end
		end

		if anyCollapseActive then
			disableCollapseControls()
		end

		::continue::
	end
end)
