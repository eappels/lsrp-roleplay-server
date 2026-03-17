local uiOpen = false
local latestInventory = {
	slots = 0,
	maxWeight = 0,
	items = {}
}
local latestTransferTarget = nil

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

local function sendTransferTargetToNui(targetPayload)
	if type(targetPayload) ~= 'table' then
		SendNUIMessage({
			action = 'clearTransferTarget'
		})
		return
	end

	SendNUIMessage({
		action = 'setTransferTarget',
		target = {
			targetId = math.floor(tonumber(targetPayload.targetId) or 0),
			targetName = tostring(targetPayload.targetName or 'Player'),
			targetInventory = normalizeInventoryPayload(targetPayload.targetInventory)
		}
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
		sendTransferTargetToNui(latestTransferTarget)
	else
		latestTransferTarget = nil
		sendTransferTargetToNui(nil)
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
	latestTransferTarget = nil

	if uiOpen then
		sendInventoryToNui(latestInventory)
		sendTransferTargetToNui(nil)
		return
	end

	setUiOpen(true)
end)

RegisterNetEvent('lsrp_inventory:client:syncInventory', function(inventory)
	latestInventory = normalizeInventoryPayload(inventory)

	if uiOpen then
		sendInventoryToNui(latestInventory)
	end
end)

RegisterNetEvent('lsrp_inventory:client:syncTransferTarget', function(targetPayload)
	if type(targetPayload) ~= 'table' then
		latestTransferTarget = nil
		if uiOpen then
			sendTransferTargetToNui(nil)
		end
		return
	end

	latestTransferTarget = {
		targetId = math.floor(tonumber(targetPayload.targetId) or 0),
		targetName = tostring(targetPayload.targetName or 'Player'),
		targetInventory = normalizeInventoryPayload(targetPayload.targetInventory or {})
	}

	if uiOpen then
		sendTransferTargetToNui(latestTransferTarget)
	end
end)

RegisterNUICallback('closeInventory', function(_, cb)
	setUiOpen(false)
	cb({ ok = true })
end)

RegisterNUICallback('requestInventory', function(_, cb)
	requestOpenInventory()
	cb({ ok = true })
end)

RegisterNUICallback('requestTransferTargetInventory', function(data, cb)
	if type(data) ~= 'table' then
		cb({ ok = false, error = 'invalid_payload' })
		return
	end

	local targetId = math.floor(tonumber(data.targetId) or 0)
	if targetId < 1 then
		cb({ ok = false, error = 'invalid_target' })
		return
	end

	TriggerServerEvent('lsrp_inventory:server:requestTransferTargetInventory', targetId)
	cb({ ok = true })
end)

RegisterNUICallback('transferItem', function(data, cb)
	if type(data) ~= 'table' then
		cb({ ok = false, error = 'invalid_payload' })
		return
	end

	local targetId = math.floor(tonumber(data.targetId) or 0)
	local fromSlot = math.floor(tonumber(data.fromSlot) or 0)
	local amount = math.floor(tonumber(data.amount) or 1)

	if targetId < 1 or fromSlot < 1 then
		cb({ ok = false, error = 'invalid_params' })
		return
	end

	if amount < 1 then
		amount = 1
	end

	TriggerServerEvent('lsrp_inventory:server:transferItemToPlayer', targetId, fromSlot, amount)
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
