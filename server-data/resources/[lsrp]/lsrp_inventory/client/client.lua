local uiOpen = false
local latestInventory = {
	slots = 0,
	maxWeight = 0,
	items = {}
}

local function normalizeInventoryPayload(raw)
	raw = type(raw) == 'table' and raw or {}

	local slots = math.max(1, math.floor(tonumber(raw.slots) or 6))
	local maxWeight = math.max(0, math.floor(tonumber(raw.maxWeight) or 0))
	local items = type(raw.items) == 'table' and raw.items or {}

	return {
		slots = slots,
		maxWeight = maxWeight,
		items = items
	}
end

local function sendInventoryToNui(inventory)
	SendNUIMessage({
		action = 'setInventoryData',
		inventory = normalizeInventoryPayload(inventory)
	})
end

local function setUiOpen(shouldOpen)
	if uiOpen == shouldOpen then
		return
	end

	uiOpen = shouldOpen
	SetNuiFocus(shouldOpen, shouldOpen)

	SendNUIMessage({
		action = 'setVisible',
		visible = shouldOpen
	})

	if shouldOpen then
		sendInventoryToNui(latestInventory)
	end
end

local function requestOpenInventory()
	TriggerServerEvent('lsrp_inventory:server:requestOpen')
end

local function toggleInventory()
	if uiOpen then
		setUiOpen(false)
		return
	end

	requestOpenInventory()
end

RegisterNetEvent('lsrp_inventory:client:receiveInventory', function(inventory)
	latestInventory = normalizeInventoryPayload(inventory)

	if uiOpen then
		sendInventoryToNui(latestInventory)
		return
	end

	setUiOpen(true)
end)

RegisterNUICallback('closeInventory', function(_, cb)
	setUiOpen(false)
	cb({ ok = true })
end)

RegisterNUICallback('requestInventory', function(_, cb)
	requestOpenInventory()
	cb({ ok = true })
end)

RegisterCommand('inventory', function()
	toggleInventory()
end, false)

RegisterCommand('+openInventory', function()
	toggleInventory()
end, false)

RegisterCommand('-openInventory', function()
	-- Required by RegisterKeyMapping (+/- command pair).
end, false)

RegisterKeyMapping('+openInventory', 'Open inventory', 'keyboard', 'I')

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	if uiOpen then
		SetNuiFocus(false, false)
	end
end)

print('[lsrp_inventory] Client script loaded')
