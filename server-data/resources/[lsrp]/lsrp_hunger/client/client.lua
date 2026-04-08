local function getHungerConfig()
	return (Config and Config.Hunger) or {}
end

local currentHunger = nil
local hungerCollapseActive = false
local hungerCollapseStartedAt = 0
local hungerKnockoutPoseApplied = false

local KNOCKOUT_ANIM_DICT = 'dead'
local KNOCKOUT_ANIM_NAME = 'dead_a'
local COLLAPSE_RAGDOLL_MS = 1200
local COLLAPSE_POSE_DELAY_MS = 1300

local BLOCKED_CONTROLS = {
	21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 44, 45, 75, 140, 141, 142, 143
}

local function getMaxHunger()
	return math.max(1, math.floor(tonumber(getHungerConfig().maxHunger) or 100))
end

local function normalizeHunger(value)
	local hunger = math.floor(tonumber(value) or getMaxHunger())
	if hunger < 0 then
		return 0
	end

	local maxHunger = getMaxHunger()
	if hunger > maxHunger then
		return maxHunger
	end

	return hunger
end

local function getHungerPercentValue(hunger)
	local maxHunger = getMaxHunger()
	if maxHunger <= 0 then
		maxHunger = 100
	end

	hunger = normalizeHunger(hunger)
	return math.floor(((hunger / maxHunger) * 100.0) + 0.5)
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
	if text ~= '' then
		print(('[lsrp_hunger] %s'):format(text))
	end
end

local function clearHungerCollapseState()
	hungerCollapseActive = false
	hungerCollapseStartedAt = 0
	hungerKnockoutPoseApplied = false
	LocalPlayer.state:set('lsrp_hunger_collapsed', false, true)

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

RegisterNetEvent('lsrp_hunger:client:update', function(hunger)
	currentHunger = normalizeHunger(hunger)
	TriggerEvent('lsrp_hud:client:setNeedPercent', 'hunger', getHungerPercentValue(currentHunger))
end)

RegisterNetEvent('lsrp_hunger:client:notify', function(message)
	showNotification(message)
end)

RegisterNetEvent('lsrp_hunger:client:revive', function()
	clearHungerCollapseState()
end)

RegisterNetEvent('lsrp_hunger:client:applyDamage', function(amount)
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

AddEventHandler('onClientResourceStart', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	TriggerServerEvent('lsrp_hunger:server:requestSync')
end)

AddEventHandler('playerSpawned', function()
	clearHungerCollapseState()
	TriggerServerEvent('lsrp_hunger:server:requestSync')
end)

exports('getCurrentHunger', function()
	if currentHunger ~= nil then
		return currentHunger
	end

	return normalizeHunger(LocalPlayer and LocalPlayer.state and LocalPlayer.state.lsrp_hunger)
end)

exports('getMaxHunger', function()
	return getMaxHunger()
end)

CreateThread(function()
	while true do
		Wait(0)

		if currentHunger == nil then
			goto continue
		end

		local ped = PlayerPedId()
		if ped == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) then
			goto continue
		end

		if currentHunger <= 0 and not hungerCollapseActive then
			hungerCollapseActive = true
			hungerCollapseStartedAt = GetGameTimer()
			hungerKnockoutPoseApplied = false
			LocalPlayer.state:set('lsrp_hunger_collapsed', true, true)
			showNotification('You collapse from starvation and cannot move.')
			FreezeEntityPosition(ped, false)
			SetPedCanRagdoll(ped, true)
			applyCollapseRagdoll(ped)
		end

		if not hungerCollapseActive then
			goto continue
		end

		disableCollapseControls()
		if shouldSuspendCollapsePose(ped) then
			FreezeEntityPosition(ped, false)
			SetPedCanRagdoll(ped, true)
			goto continue
		end

		if not hungerKnockoutPoseApplied and hungerCollapseStartedAt > 0 and (GetGameTimer() - hungerCollapseStartedAt) >= COLLAPSE_POSE_DELAY_MS then
			hungerKnockoutPoseApplied = true
			applyKnockedOutPose(ped)
		elseif hungerKnockoutPoseApplied and not IsEntityPlayingAnim(ped, KNOCKOUT_ANIM_DICT, KNOCKOUT_ANIM_NAME, 3) then
			applyKnockedOutPose(ped)
		end

		::continue::
	end
end)