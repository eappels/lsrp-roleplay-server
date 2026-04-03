local function getThirstConfig()
	return (Config and Config.Thirst) or {}
end

local currentThirst = nil
local thirstCollapseActive = false
local thirstCollapseStartedAt = 0
local thirstKnockoutPoseApplied = false

local KNOCKOUT_ANIM_DICT = 'dead'
local KNOCKOUT_ANIM_NAME = 'dead_a'
local COLLAPSE_RAGDOLL_MS = 1200
local COLLAPSE_POSE_DELAY_MS = 1300

local BLOCKED_CONTROLS = {
	21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 44, 45, 75, 140, 141, 142, 143
}

local function getMaxThirst()
	return math.max(1, math.floor(tonumber(getThirstConfig().maxThirst) or 100))
end

local function normalizeThirst(value)
	local thirst = math.floor(tonumber(value) or getMaxThirst())
	if thirst < 0 then
		return 0
	end

	local maxThirst = getMaxThirst()
	if thirst > maxThirst then
		return maxThirst
	end

	return thirst
end

local function getThirstPercentValue(thirst)
	local maxThirst = getMaxThirst()
	if maxThirst <= 0 then
		maxThirst = 100
	end

	thirst = normalizeThirst(thirst)
	return math.floor(((thirst / maxThirst) * 100.0) + 0.5)
end

local function showNotification(message)
	local text = tostring(message or '')
	if text == '' then
		return
	end

	BeginTextCommandThefeedPost('STRING')
	AddTextComponentSubstringPlayerName(text)
	EndTextCommandThefeedPostTicker(false, false)
	if text ~= '' then
		print(('[lsrp_thirst] %s'):format(text))
	end
end

local function clearThirstCollapseState()
	thirstCollapseActive = false
	thirstCollapseStartedAt = 0
	thirstKnockoutPoseApplied = false

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

RegisterNetEvent('lsrp_thirst:client:update', function(thirst)
	currentThirst = normalizeThirst(thirst)
	TriggerEvent('lsrp_hud:client:setNeedPercent', 'thirst', getThirstPercentValue(currentThirst))
end)

RegisterNetEvent('lsrp_thirst:client:notify', function(message)
	showNotification(message)
end)

RegisterNetEvent('lsrp_thirst:client:revive', function()
	clearThirstCollapseState()
end)

RegisterNetEvent('lsrp_thirst:client:applyDamage', function(amount)
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

	TriggerServerEvent('lsrp_thirst:server:requestSync')
end)

AddEventHandler('playerSpawned', function()
	clearThirstCollapseState()
	TriggerServerEvent('lsrp_thirst:server:requestSync')
end)

exports('getCurrentThirst', function()
	if currentThirst ~= nil then
		return currentThirst
	end

	return normalizeThirst(LocalPlayer and LocalPlayer.state and LocalPlayer.state.lsrp_thirst)
end)

exports('getMaxThirst', function()
	return getMaxThirst()
end)

CreateThread(function()
	while true do
		Wait(0)

		if currentThirst == nil then
			goto continue
		end

		local ped = PlayerPedId()
		if ped == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) then
			goto continue
		end

		if currentThirst <= 0 and not thirstCollapseActive then
			thirstCollapseActive = true
			thirstCollapseStartedAt = GetGameTimer()
			thirstKnockoutPoseApplied = false
			showNotification('You collapse from dehydration and cannot move.')
			FreezeEntityPosition(ped, false)
			SetPedCanRagdoll(ped, true)
			applyCollapseRagdoll(ped)
		end

		if not thirstCollapseActive then
			goto continue
		end

		disableCollapseControls()
		if not thirstKnockoutPoseApplied and thirstCollapseStartedAt > 0 and (GetGameTimer() - thirstCollapseStartedAt) >= COLLAPSE_POSE_DELAY_MS then
			thirstKnockoutPoseApplied = true
			applyKnockedOutPose(ped)
		end

		::continue::
	end
end)