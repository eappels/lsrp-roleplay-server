local uiOpen = false
local latestInventory = {
	slots = 0,
	maxWeight = 0,
	items = {}
}
local latestTarget = nil
local worldDrops = {}
local latestNearbyPlayers = {}

local function normalizeInventoryPayload(raw)
	raw = type(raw) == 'table' and raw or {}
	return {
		slots = math.max(1, math.floor(tonumber(raw.slots) or 1)),
		maxWeight = math.max(0, math.floor(tonumber(raw.maxWeight) or 0)),
		items = type(raw.items) == 'table' and raw.items or {}
	}
end

local function getTransferRange()
	return math.max(1.0, tonumber(Config and Config.Inventory and Config.Inventory.transferRange) or 4.0)
end

local function buildNearbyPlayersPayload()
	local payload = {}
	local playerPed = PlayerPedId()
	if playerPed == 0 then
		return payload
	end

	local playerCoords = GetEntityCoords(playerPed)
	for _, playerId in ipairs(GetActivePlayers()) do
		if playerId ~= PlayerId() then
			local targetPed = GetPlayerPed(playerId)
			if targetPed ~= 0 then
				local targetCoords = GetEntityCoords(targetPed)
				local distance = #(playerCoords - targetCoords)
				if distance <= getTransferRange() then
					payload[#payload + 1] = {
						targetId = GetPlayerServerId(playerId),
						targetName = GetPlayerName(playerId) or ('ID ' .. tostring(GetPlayerServerId(playerId))),
						distance = math.floor((distance * 10.0) + 0.5) / 10.0
					}
				end
			end
		end
	end

	table.sort(payload, function(left, right)
		if left.distance == right.distance then
			return left.targetId < right.targetId
		end
		return left.distance < right.distance
	end)

	return payload
end

local function refreshNearbyPlayers()
	latestNearbyPlayers = buildNearbyPlayersPayload()
	if uiOpen then
		SendNUIMessage({ action = 'setNearbyPlayers', players = latestNearbyPlayers })
	end
	return latestNearbyPlayers
end

local function setUiOpen(shouldOpen)
	if uiOpen == shouldOpen then
		return
	end

	uiOpen = shouldOpen
	SetNuiFocus(shouldOpen, shouldOpen)
	SendNUIMessage({ action = 'setVisible', visible = shouldOpen })

	if shouldOpen then
		SendNUIMessage({ action = 'setInventoryData', inventory = latestInventory })
		SendNUIMessage({ action = 'setTransferTarget', target = latestTarget })
		SendNUIMessage({ action = 'setNearbyPlayers', players = latestNearbyPlayers })
	else
		latestTarget = nil
		SendNUIMessage({ action = 'clearTransferTarget' })
	end
end

local function requestOpenInventory()
	refreshNearbyPlayers()
	TriggerServerEvent('lsrp_inventory:server:requestOpen')
end

RegisterNetEvent('lsrp_inventory:client:receiveInventory', function(inventory)
	latestInventory = normalizeInventoryPayload(inventory)
	if uiOpen then
		SendNUIMessage({ action = 'setInventoryData', inventory = latestInventory })
	else
		setUiOpen(true)
	end
end)

RegisterNetEvent('lsrp_inventory:client:syncInventory', function(inventory)
	latestInventory = normalizeInventoryPayload(inventory)
	if uiOpen then
		SendNUIMessage({ action = 'setInventoryData', inventory = latestInventory })
	end
end)

RegisterNetEvent('lsrp_inventory:client:syncTransferTarget', function(targetPayload)
	latestTarget = type(targetPayload) == 'table' and targetPayload or nil
	if uiOpen then
		if latestTarget then
			SendNUIMessage({ action = 'setTransferTarget', target = latestTarget })
		else
			SendNUIMessage({ action = 'clearTransferTarget' })
		end
	end
end)

RegisterNetEvent('lsrp_inventory:client:setWorldDrops', function(drops)
	worldDrops = {}
	for _, drop in ipairs(type(drops) == 'table' and drops or {}) do
		worldDrops[tonumber(drop.id)] = drop
	end
end)

RegisterNetEvent('lsrp_inventory:client:addWorldDrop', function(drop)
	if type(drop) ~= 'table' or not drop.id then
		return
	end
	worldDrops[tonumber(drop.id)] = drop
end)

RegisterNetEvent('lsrp_inventory:client:removeWorldDrop', function(dropId)
	worldDrops[tonumber(dropId)] = nil
end)

RegisterNetEvent('lsrp_inventory:client:setNearbyPlayers', function(players)
	latestNearbyPlayers = type(players) == 'table' and players or {}
	if uiOpen then
		SendNUIMessage({ action = 'setNearbyPlayers', players = latestNearbyPlayers })
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
	local targetId = math.floor(tonumber(data and data.targetId) or 0)
	if targetId < 1 then
		cb({ ok = false, error = 'invalid_target' })
		return
	end
	TriggerServerEvent('lsrp_inventory:server:requestTransferTargetInventory', targetId)
	cb({ ok = true })
end)

RegisterNUICallback('requestNearbyPlayers', function(_, cb)
	refreshNearbyPlayers()
	cb({ ok = true })
end)

RegisterNUICallback('moveItem', function(data, cb)
	local fromSlot = math.floor(tonumber(data and data.fromSlot) or 0)
	local toSlot = math.floor(tonumber(data and data.toSlot) or 0)
	local amount = math.floor(tonumber(data and data.amount) or 1)
	if fromSlot < 1 or toSlot < 1 then
		cb({ ok = false, error = 'invalid_slots' })
		return
	end
	TriggerServerEvent('lsrp_inventory:server:moveItem', fromSlot, toSlot, amount)
	cb({ ok = true })
end)

RegisterNUICallback('giveItem', function(data, cb)
	local targetId = math.floor(tonumber(data and data.targetId) or 0)
	local fromSlot = math.floor(tonumber(data and data.fromSlot) or 0)
	local toSlot = math.floor(tonumber(data and data.toSlot) or 0)
	local amount = math.floor(tonumber(data and data.amount) or 1)
	if targetId < 1 or fromSlot < 1 then
		cb({ ok = false, error = 'invalid_params' })
		return
	end
	TriggerServerEvent('lsrp_inventory:server:giveItem', targetId, fromSlot, toSlot, amount)
	cb({ ok = true })
end)

RegisterNUICallback('dropItem', function(data, cb)
	local fromSlot = math.floor(tonumber(data and data.fromSlot) or 0)
	local amount = math.floor(tonumber(data and data.amount) or 1)
	if fromSlot < 1 then
		cb({ ok = false, error = 'invalid_slot' })
		return
	end
	TriggerServerEvent('lsrp_inventory:server:dropItem', fromSlot, amount)
	cb({ ok = true })
end)

RegisterCommand('inventory', function()
	if uiOpen then
		setUiOpen(false)
	else
		requestOpenInventory()
	end
end, false)

RegisterCommand('+openInventory', function()
	if uiOpen then
		setUiOpen(false)
	else
		requestOpenInventory()
	end
end, false)

RegisterCommand('-openInventory', function()
	-- Required for RegisterKeyMapping.
end, false)

RegisterKeyMapping('+openInventory', 'Open inventory', 'keyboard', 'I')

Citizen.CreateThread(function()
	while true do
		if uiOpen then
			refreshNearbyPlayers()
			Citizen.Wait(750)
		else
			Citizen.Wait(250)
		end
	end
end)

Citizen.CreateThread(function()
	TriggerServerEvent('lsrp_inventory:server:requestWorldDrops')
	while true do
		Citizen.Wait(0)
		local ped = PlayerPedId()
		local coords = GetEntityCoords(ped)
		for dropId, drop in pairs(worldDrops) do
			local position = drop.position or {}
			local dropCoords = vector3(position.x or 0.0, position.y or 0.0, position.z or 0.0)
			local distance = #(coords - dropCoords)
			if distance < 35.0 then
				DrawMarker(2, dropCoords.x, dropCoords.y, dropCoords.z + 0.15, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.18, 0.18, 0.18, 233, 196, 106, 180, false, false, 2, true, nil, nil, false)
			end
			if distance < 1.6 then
				SetTextComponentFormat('STRING')
				AddTextComponentString(('Press ~INPUT_CONTEXT~ to pick up %s x%d'):format(tostring((drop.item and (drop.item.label or drop.item.name)) or 'Item'), math.floor(tonumber(drop.item and drop.item.count) or 1)))
				DisplayHelpTextFromStringLabel(0, 0, 1, -1)
				if IsControlJustReleased(0, 38) then
					TriggerServerEvent('lsrp_inventory:server:pickupWorldDrop', dropId)
				end
			end
		end
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end
	SetNuiFocus(false, false)
end)

print('[lsrp_inventory] Rebuilt client loaded')
