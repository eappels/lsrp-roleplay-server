local function getHungerConfig()
	return (Config and Config.Hunger) or {}
end

local currentHunger = nil

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

local function showNotification(message)
	local text = tostring(message or '')
	if text == '' then
		return
	end

	BeginTextCommandThefeedPost('STRING')
	AddTextComponentSubstringPlayerName(text)
	EndTextCommandThefeedPostTicker(false, false)
	if text ~= '' then
		print(('[lsrp_hunger] %s'):format(text))
	end
end

RegisterNetEvent('lsrp_hunger:client:update', function(hunger)
	currentHunger = normalizeHunger(hunger)
end)

RegisterNetEvent('lsrp_hunger:client:notify', function(message)
	showNotification(message)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	TriggerServerEvent('lsrp_hunger:server:requestSync')
end)

AddEventHandler('playerSpawned', function()
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