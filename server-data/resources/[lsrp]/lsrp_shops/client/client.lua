local uiOpen = false
local activeStore = nil
local currentBalance = 0
local currentFormattedBalance = 'LS$0'
local storeBlips = {}

local function trimString(value)
	if value == nil then
		return nil
	end

	local trimmed = tostring(value):gsub('^%s+', ''):gsub('%s+$', '')
	if trimmed == '' then
		return nil
	end

	return trimmed
end

local function normalizeIdentifier(value)
	local trimmed = trimString(value)
	if not trimmed then
		return nil
	end

	return string.lower(trimmed)
end

local function formatFallbackCurrency(value)
	local amount = math.max(0, math.floor(tonumber(value) or 0))
	local formatted = tostring(amount)

	while true do
		local updated, replacements = formatted:gsub('^(%-?%d+)(%d%d%d)', '%1,%2')
		formatted = updated

		if replacements == 0 then
			break
		end
	end

	return 'LS$' .. formatted
end

local function notify(message)
	BeginTextCommandThefeedPost('STRING')
	AddTextComponentSubstringPlayerName(tostring(message or ''))
	EndTextCommandThefeedPostTicker(false, true)
end

local function showHelpPrompt(message)
	BeginTextCommandDisplayHelp('STRING')
	AddTextComponentSubstringPlayerName(tostring(message or ''))
	EndTextCommandDisplayHelp(0, false, true, -1)
end

local function getStoreById(storeId)
	local normalizedStoreId = normalizeIdentifier(storeId)
	if not normalizedStoreId then
		return nil
	end

	for _, store in ipairs(Config.Stores or {}) do
		if normalizeIdentifier(store.id) == normalizedStoreId then
			return store
		end
	end

	return nil
end

local function getCatalogById(catalogId)
	local normalizedCatalogId = normalizeIdentifier(catalogId)
	if not normalizedCatalogId then
		return nil
	end

	for id, catalog in pairs(Config.Catalogs or {}) do
		if normalizeIdentifier(id) == normalizedCatalogId or normalizeIdentifier(catalog.id) == normalizedCatalogId then
			return catalog
		end
	end

	return nil
end

local function buildStoreItems(store)
	local catalog = getCatalogById(store and store.catalogId)
	local items = {}

	for _, item in ipairs((catalog and catalog.items) or {}) do
		local price = math.max(0, math.floor(tonumber(item.price) or 0))
		items[#items + 1] = {
			name = trimString(item.name),
			label = trimString(item.label) or trimString(item.name) or 'Item',
			price = price,
			formattedPrice = formatFallbackCurrency(price),
			maxQuantity = math.max(1, math.floor(tonumber(item.maxQuantity) or 1)),
			description = trimString(item.description) or 'Store item.'
		}
	end

	table.sort(items, function(left, right)
		if left.price == right.price then
			return left.label < right.label
		end

		return left.price < right.price
	end)

	return items, catalog
end

local function setBalance(balance, formattedBalance)
	currentBalance = math.max(0, math.floor(tonumber(balance) or 0))
	currentFormattedBalance = trimString(formattedBalance) or formatFallbackCurrency(currentBalance)

	if uiOpen then
		SendNUIMessage({
			action = 'updateBalance',
			balance = currentBalance,
			formattedBalance = currentFormattedBalance
		})
	end
end

local function closeShop()
	if not uiOpen then
		return
	end

	uiOpen = false
	activeStore = nil
	SetNuiFocus(false, false)
	SendNUIMessage({ action = 'closeShop' })
end

local function openShop(store)
	if not store then
		return
	end

	local items, catalog = buildStoreItems(store)
	if #items == 0 then
		notify('This store has no inventory configured.')
		return
	end

	activeStore = store
	uiOpen = true
	SetNuiFocus(true, true)

	SendNUIMessage({
		action = 'openShop',
		shop = {
			id = store.id,
			name = trimString(store.name) or 'Convenience Store',
			subtitle = trimString(store.subtitle) or 'Quick essentials.',
			catalogLabel = trimString(catalog and catalog.label) or 'Store Items'
		},
		items = items,
		balance = currentBalance,
		formattedBalance = currentFormattedBalance
	})

	TriggerServerEvent('lsrp_shops:server:requestBalance', store.id)
end

local function destroyBlips()
	for _, blip in ipairs(storeBlips) do
		RemoveBlip(blip)
	end

	storeBlips = {}
end

local function createBlips()
	destroyBlips()

	local defaultBlip = Config.DefaultBlip or {}
	for _, store in ipairs(Config.Stores or {}) do
		local blipConfig = store.blip
		if blipConfig == nil then
			blipConfig = defaultBlip
		end

		if blipConfig and blipConfig.enabled ~= false then
			local coords = store.interaction
			local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
			SetBlipSprite(blip, math.floor(tonumber(blipConfig.sprite) or 52))
			SetBlipDisplay(blip, 4)
			SetBlipScale(blip, tonumber(blipConfig.scale) or 0.75)
			SetBlipColour(blip, math.floor(tonumber(blipConfig.color) or 2))
			SetBlipAsShortRange(blip, true)
			BeginTextCommandSetBlipName('STRING')
			AddTextComponentSubstringPlayerName(trimString(blipConfig.label) or trimString(store.name) or 'Convenience Store')
			EndTextCommandSetBlipName(blip)
			storeBlips[#storeBlips + 1] = blip
		end
	end
end

RegisterNetEvent('lsrp_shops:client:updateBalance', function(payload)
	payload = type(payload) == 'table' and payload or {}
	setBalance(payload.balance, payload.formattedBalance)
end)

RegisterNetEvent('lsrp_shops:client:purchaseResult', function(payload)
	payload = type(payload) == 'table' and payload or {}

	if payload.balance ~= nil or payload.formattedBalance ~= nil then
		setBalance(payload.balance, payload.formattedBalance)
	end

	if payload.success then
		SendNUIMessage({
			action = 'purchaseResult',
			success = true,
			message = trimString(payload.message) or 'Purchase completed.'
		})
	else
		SendNUIMessage({
			action = 'purchaseResult',
			success = false,
			message = trimString(payload.message) or 'Purchase failed.'
		})
	end
	end)

RegisterNetEvent('lsrp_shops:open', function(storeId)
	local store = getStoreById(storeId)
	if not store then
		notify('Store location is not configured.')
		return
	end

	openShop(store)
end)

RegisterNUICallback('close', function(_, cb)
	closeShop()
	cb({ ok = true })
end)

RegisterNUICallback('purchase', function(payload, cb)
	if not uiOpen or not activeStore then
		cb({ ok = false, error = 'shop_not_open' })
		return
	end

	payload = type(payload) == 'table' and payload or {}
	local itemName = trimString(payload.itemName)
	local quantity = math.max(1, math.floor(tonumber(payload.quantity) or 1))

	if not itemName then
		cb({ ok = false, error = 'invalid_item' })
		return
	end

	TriggerServerEvent('lsrp_shops:server:purchaseItem', {
		storeId = activeStore.id,
		itemName = itemName,
		quantity = quantity
	})

	cb({ ok = true })
end)

CreateThread(function()
	createBlips()

	while true do
		local waitMs = 750
		local playerPed = PlayerPedId()

		if playerPed ~= 0 and DoesEntityExist(playerPed) then
			local playerCoords = GetEntityCoords(playerPed)
			local closestStore = nil
			local closestDistance = nil

			for _, store in ipairs(Config.Stores or {}) do
				local coords = store.interaction
				local distance = #(playerCoords - coords)

				if distance <= (tonumber(Config.DrawDistance) or 20.0) then
					waitMs = 0

					if Config.Marker and Config.Marker.enabled ~= false then
						DrawMarker(
							math.floor(tonumber(Config.Marker.type) or 27),
							coords.x,
							coords.y,
							coords.z - 0.96,
							0.0,
							0.0,
							0.0,
							0.0,
							0.0,
							0.0,
							(Config.Marker.scale and Config.Marker.scale.x) or 0.45,
							(Config.Marker.scale and Config.Marker.scale.y) or 0.45,
							(Config.Marker.scale and Config.Marker.scale.z) or 0.45,
							(Config.Marker.color and Config.Marker.color.r) or 91,
							(Config.Marker.color and Config.Marker.color.g) or 197,
							(Config.Marker.color and Config.Marker.color.b) or 255,
							(Config.Marker.color and Config.Marker.color.a) or 185,
							Config.Marker.bobUpAndDown == true,
							false,
							2,
							Config.Marker.rotate == true,
							nil,
							nil,
							false
						)
					end
				end

				if not closestDistance or distance < closestDistance then
					closestStore = store
					closestDistance = distance
				end
			end

			if uiOpen and activeStore and activeStore.interaction then
				local distanceFromActiveStore = #(playerCoords - activeStore.interaction)
				if distanceFromActiveStore > (tonumber(Config.AutoCloseDistance) or 8.0) then
					closeShop()
					notify('You stepped away from the store.')
				end
			end

			if not uiOpen and closestStore and closestDistance and closestDistance <= (tonumber(closestStore.interactionRadius) or 1.8) then
				showHelpPrompt(trimString(Config.OpenPrompt) or 'Press ~INPUT_CONTEXT~ to browse goods')
				if IsControlJustPressed(0, math.floor(tonumber(Config.InteractionKey) or 38)) then
					openShop(closestStore)
				end
			end
		end

		Wait(waitMs)
	end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	closeShop()
	destroyBlips()
end)