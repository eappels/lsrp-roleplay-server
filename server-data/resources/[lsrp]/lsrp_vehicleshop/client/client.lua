local uiOpen = false
local activeShop = nil
local vehicleEditorOpen = false
local currentBalance = 0
local currentFormattedBalance = 'LS$0'
local demoVehicles = {}
local DEMO_MODEL_LOAD_TIMEOUT_MS = 8000
local DEMO_COLLISION_TIMEOUT_MS = 2500
local DEMO_GROUND_SNAP_RETRIES = 24
local DEMO_SPAWN_HEIGHT_OFFSET = 1.25
local DEMO_FLOAT_HEIGHT_THRESHOLD = 0.35
local DEMO_MAX_SETTLE_ATTEMPTS = 8
local DEMO_SETTLE_RETRY_INTERVAL_MS = 500
local spawnedDemoShops = {}

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
	AddTextComponentSubstringPlayerName(tostring(message))
	EndTextCommandDisplayHelp(0, false, true, -1)
end

local function getCategoryLabel(categoryId)
	local normalized = normalizeIdentifier(categoryId)

	for _, category in ipairs(Config.Categories or {}) do
		if normalizeIdentifier(category.id) == normalized then
			return trimString(category.label) or normalized
		end
	end

	return normalized or 'Unknown'
end

local function getAllowedCategorySet(shop)
	local allowedSet = {}

	if type(shop.allowedCategories) ~= 'table' or #shop.allowedCategories == 0 then
		return allowedSet
	end

	for _, categoryId in ipairs(shop.allowedCategories) do
		local normalized = normalizeIdentifier(categoryId)
		if normalized then
			allowedSet[normalized] = true
		end
	end

	return allowedSet
end

local function getVehiclesForShop(shop)
	local vehicles = {}
	local allowedCategories = getAllowedCategorySet(shop)
	local hasFilter = next(allowedCategories) ~= nil

	for _, vehicle in ipairs(Config.Vehicles or {}) do
		local model = normalizeIdentifier(vehicle.model)
		local category = normalizeIdentifier(vehicle.category)
		local price = tonumber(vehicle.price)

		if model and category and price and price > 0 then
			if not hasFilter or allowedCategories[category] then
				vehicles[#vehicles + 1] = {
					model = model,
					label = trimString(vehicle.label) or model,
					category = category,
					categoryLabel = getCategoryLabel(category),
					price = math.floor(price),
					formattedPrice = formatFallbackCurrency(price),
					speed = math.max(1, math.min(10, math.floor(tonumber(vehicle.speed) or 5))),
					accel = math.max(1, math.min(10, math.floor(tonumber(vehicle.accel) or 5))),
					handling = math.max(1, math.min(10, math.floor(tonumber(vehicle.handling) or 5))),
					braking = math.max(1, math.min(10, math.floor(tonumber(vehicle.braking) or 5)))
				}
			end
		end
	end

	table.sort(vehicles, function(a, b)
		if a.price == b.price then
			return a.label < b.label
		end

		return a.price < b.price
	end)

	return vehicles
end

local function getCategoriesForShop(shop, vehicles)
	local categories = {}

	local presentCategories = {}
	for _, vehicle in ipairs(vehicles) do
		presentCategories[vehicle.category] = true
	end

	local allowedCategories = getAllowedCategorySet(shop)
	local hasFilter = next(allowedCategories) ~= nil

	for _, category in ipairs(Config.Categories or {}) do
		local categoryId = normalizeIdentifier(category.id)
		if categoryId and presentCategories[categoryId] then
			if not hasFilter or allowedCategories[categoryId] then
				categories[#categories + 1] = {
					id = categoryId,
					label = trimString(category.label) or categoryId
				}
			end
		end
	end

	return categories
end

local function setUiBalance(balance, formattedBalance)
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
	activeShop = nil
	SetNuiFocus(false, false)

	SendNUIMessage({
		action = 'closeShop'
	})
end

local function openShop(shop)
	if not shop or uiOpen then
		return
	end

	local vehicles = getVehiclesForShop(shop)
	if #vehicles == 0 then
		notify('This dealership currently has no inventory.')
		return
	end

	local categories = getCategoriesForShop(shop, vehicles)

	activeShop = shop
	uiOpen = true

	SetNuiFocus(true, true)

	SendNUIMessage({
		action = 'openShop',
		shop = {
			id = shop.id,
			name = shop.name,
			subtitle = shop.subtitle,
			deliveryParkingZone = shop.deliveryParkingZone or Config.DefaultDeliveryParkingZone
		},
		categories = categories,
		vehicles = vehicles,
		balance = currentBalance,
		formattedBalance = currentFormattedBalance
	})

	TriggerServerEvent('lsrp_vehicleshop:server:requestBalance')
end

local function getShopById(shopId)
	local normalizedShopId = normalizeIdentifier(shopId)
	if not normalizedShopId then
		return nil
	end

	for _, shop in ipairs(Config.Shops or {}) do
		if normalizeIdentifier(shop.id) == normalizedShopId then
			shop.id = normalizedShopId
			shop.name = trimString(shop.name) or normalizedShopId
			return shop
		end
	end

	return nil
end

local function getNearestShop(maxDistance)
	local playerPed = PlayerPedId()
	local coords = GetEntityCoords(playerPed)

	local nearestShop = nil
	local nearestDistance = maxDistance or 9999.0

	for _, shop in ipairs(Config.Shops or {}) do
		if shop.interaction then
			local distance = #(coords - shop.interaction)
			if distance <= nearestDistance then
				nearestDistance = distance
				nearestShop = shop
			end
		end
	end

	return nearestShop, nearestDistance
end

local function clearDemoVehicles()
	for index = #demoVehicles, 1, -1 do
		local entry = demoVehicles[index]
		local vehicle = entry

		if type(entry) == 'table' then
			vehicle = entry.entity
		end

		if vehicle and DoesEntityExist(vehicle) then
			DeleteEntity(vehicle)
		end

		demoVehicles[index] = nil
	end
end

local function loadVehicleModel(modelHash)
	if not IsModelInCdimage(modelHash) or not IsModelAVehicle(modelHash) then
		return false
	end

	RequestModel(modelHash)

	local timeoutAt = GetGameTimer() + DEMO_MODEL_LOAD_TIMEOUT_MS
	while not HasModelLoaded(modelHash) do
		RequestModel(modelHash)

		if GetGameTimer() >= timeoutAt then
			return false
		end

		Wait(0)
	end

	return true
end

local function getDemoModelForDisplay(shopCatalog, displayIndex, configuredModel)
	if #shopCatalog == 0 then
		return nil
	end

	local explicitModel = normalizeIdentifier(configuredModel)
	if explicitModel then
		for _, vehicle in ipairs(shopCatalog) do
			if vehicle.model == explicitModel then
				return explicitModel
			end
		end
	end

	local fallbackIndex = ((displayIndex - 1) % #shopCatalog) + 1
	local fallbackVehicle = shopCatalog[fallbackIndex]
	if fallbackVehicle then
		return fallbackVehicle.model
	end

	return nil
end

local function getShopDemoKey(shop, shopIndex)
	local normalizedShopId = normalizeIdentifier(shop and shop.id)
	if normalizedShopId then
		return normalizedShopId
	end

	return ('shop_%s'):format(tostring(shopIndex or 0))
end

local function waitForDemoCollision(vehicle, x, y, z)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return false
	end

	local timeoutAt = GetGameTimer() + DEMO_COLLISION_TIMEOUT_MS
	while GetGameTimer() < timeoutAt do
		if HasCollisionLoadedAroundEntity(vehicle) then
			return true
		end

		RequestCollisionAtCoord(x + 0.0, y + 0.0, z + 0.0)
		if type(RequestAdditionalCollisionAtCoord) == 'function' then
			RequestAdditionalCollisionAtCoord(x + 0.0, y + 0.0, z + 0.0)
		end

		Wait(0)
	end

	return HasCollisionLoadedAroundEntity(vehicle)
end

local function isVehicleFloating(vehicle)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return false
	end

	local heightAboveGround = GetEntityHeightAboveGround(vehicle)
	return heightAboveGround > DEMO_FLOAT_HEIGHT_THRESHOLD
end

local function settleDemoVehicleToGround(vehicle, x, y, configuredZ, heading)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return
	end

	local targetZ = configuredZ + DEMO_SPAWN_HEIGHT_OFFSET
	SetEntityCoordsNoOffset(vehicle, x + 0.0, y + 0.0, targetZ + 0.0, false, false, false)
	SetEntityHeading(vehicle, heading + 0.0)
	SetEntityDynamic(vehicle, true)
	FreezeEntityPosition(vehicle, false)

	waitForDemoCollision(vehicle, x, y, configuredZ)

	for _ = 1, DEMO_GROUND_SNAP_RETRIES do
		SetVehicleOnGroundProperly(vehicle)

		if not isVehicleFloating(vehicle) then
			break
		end

		Wait(0)
	end

	if isVehicleFloating(vehicle) then
		local coords = GetEntityCoords(vehicle)
		local heightAboveGround = GetEntityHeightAboveGround(vehicle)
		local correction = math.min(math.max(heightAboveGround, 0.0), DEMO_SPAWN_HEIGHT_OFFSET)

		if correction > 0.0 then
			SetEntityCoordsNoOffset(vehicle, coords.x, coords.y, coords.z - correction, false, false, false)
			SetVehicleOnGroundProperly(vehicle)
		end
	end

	SetEntityHeading(vehicle, heading + 0.0)
end

local function stabilizeDemoVehicle(entry)
	if type(entry) ~= 'table' then
		return
	end

	CreateThread(function()
		for _ = 1, DEMO_MAX_SETTLE_ATTEMPTS do
			Wait(DEMO_SETTLE_RETRY_INTERVAL_MS)

			local vehicle = entry.entity
			if vehicle == 0 or not DoesEntityExist(vehicle) then
				return
			end

			if not isVehicleFloating(vehicle) then
				return
			end

			settleDemoVehicleToGround(vehicle, entry.x, entry.y, entry.z, entry.heading)
			FreezeEntityPosition(vehicle, true)
		end
	end)
end

local function spawnDemoVehiclesForShop(shop)
	if type(shop) ~= 'table' then
		return
	end

	local displays = shop.demoDisplays
	if type(displays) ~= 'table' or #displays == 0 then
		return
	end

	local shopCatalog = getVehiclesForShop(shop)
	if #shopCatalog == 0 then
		return
	end

	-- First pass: create all vehicles without freezing them so physics can load
	local pendingVehicles = {}

	for index, display in ipairs(displays) do
		local x = tonumber(display.x)
		local y = tonumber(display.y)
		local z = tonumber(display.z)
		local heading = tonumber(display.heading) or 0.0

		if x and y and z then
			local modelName = getDemoModelForDisplay(shopCatalog, index, display.model)
			if modelName then
				local modelHash = GetHashKey(modelName)
				if loadVehicleModel(modelHash) then
					local spawnZ = z + DEMO_SPAWN_HEIGHT_OFFSET
					local vehicle = CreateVehicle(modelHash, x, y, spawnZ, heading, false, false)

					if vehicle and vehicle ~= 0 then
						SetEntityAsMissionEntity(vehicle, true, true)
						SetEntityHeading(vehicle, heading)
						SetVehicleEngineOn(vehicle, false, true, true)
						SetVehicleDoorsLocked(vehicle, 2)
						SetVehicleDoorsLockedForAllPlayers(vehicle, true)
						SetVehicleUndriveable(vehicle, true)
						SetVehicleDirtLevel(vehicle, 0.0)
						SetEntityInvincible(vehicle, true)

						pendingVehicles[#pendingVehicles + 1] = {
							entity = vehicle,
							x = x,
							y = y,
							z = z,
							heading = heading
						}
					end

					SetModelAsNoLongerNeeded(modelHash)
				end
			end
		end
	end

	-- Wait for collision/physics to settle before snapping to ground and freezing
	Wait(500)

	for _, pending in ipairs(pendingVehicles) do
		local vehicle = pending.entity
		if vehicle and DoesEntityExist(vehicle) then
			settleDemoVehicleToGround(vehicle, pending.x, pending.y, pending.z, pending.heading)
			FreezeEntityPosition(vehicle, true)

			local entry = {
				entity = vehicle,
				x = pending.x,
				y = pending.y,
				z = pending.z,
				heading = pending.heading
			}

			demoVehicles[#demoVehicles + 1] = entry
			stabilizeDemoVehicle(entry)
		end
	end
end

local function spawnConfiguredDemoVehicles()
	clearDemoVehicles()
	spawnedDemoShops = {}

	for shopIndex, shop in ipairs(Config.Shops or {}) do
		spawnDemoVehiclesForShop(shop)
		spawnedDemoShops[getShopDemoKey(shop, shopIndex)] = true
	end
end

RegisterNetEvent('lsrp_vehicleshop:client:updateBalance', function(payload)
	if type(payload) ~= 'table' then
		return
	end

	setUiBalance(payload.balance, payload.formattedBalance)
end)

RegisterNetEvent('lsrp_economy:client:balanceUpdated', function(balance, currencySymbol)
	local formatted = nil
	if type(currencySymbol) == 'string' and currencySymbol ~= '' then
		local amount = math.max(0, math.floor(tonumber(balance) or 0))
		formatted = currencySymbol .. formatFallbackCurrency(amount):gsub('^LS%$', '')
	end

	setUiBalance(balance, formatted)
end)

RegisterNetEvent('lsrp_vehicleshop:client:purchaseResult', function(payload)
	if type(payload) ~= 'table' then
		return
	end

	if payload.balance ~= nil then
		setUiBalance(payload.balance, payload.formattedBalance)
	end

	if trimString(payload.message) then
		notify(payload.message)
	end

	if uiOpen then
		SendNUIMessage({
			action = 'purchaseResult',
			result = payload
		})
	end
end)

RegisterNetEvent('lsrp_vehicleshop:open', function(shopId)
	if uiOpen then
		return
	end

	local requestedShop = getShopById(shopId)
	if requestedShop then
		openShop(requestedShop)
		return
	end

	local nearestShop = getNearestShop(20.0)
	if nearestShop then
		openShop(nearestShop)
		return
	end

	notify('No dealership is nearby.')
end)

RegisterCommand('vehicleshop', function()
	if uiOpen then
		closeShop()
		return
	end

	local nearestShop = getNearestShop(20.0)
	if nearestShop then
		openShop(nearestShop)
		return
	end

	notify('No dealership is nearby.')
end, false)

RegisterKeyMapping('+openVehicleShop', 'Open nearest vehicle shop', 'keyboard', 'F6')

RegisterCommand('+openVehicleShop', function()
	if uiOpen then
		closeShop()
		return
	end

	local nearestShop = getNearestShop(20.0)
	if nearestShop then
		openShop(nearestShop)
		return
	end

	notify('No dealership is nearby.')
end, false)

RegisterCommand('-openVehicleShop', function()
	-- Required by RegisterKeyMapping (+/- command pair).
end, false)

RegisterNUICallback('close', function(_, cb)
	closeShop()
	cb({ ok = true })
end)

RegisterNUICallback('requestBalance', function(_, cb)
	TriggerServerEvent('lsrp_vehicleshop:server:requestBalance')
	cb({ ok = true })
end)

RegisterNUICallback('purchaseVehicle', function(data, cb)
	if not uiOpen or not activeShop then
		cb({ ok = false, error = 'shop_not_open' })
		return
	end

	local model = normalizeIdentifier(data and data.model)
	if not model then
		cb({ ok = false, error = 'invalid_model' })
		return
	end

	TriggerServerEvent('lsrp_vehicleshop:server:purchaseVehicle', {
		shopId = activeShop.id,
		model = model
	})

	cb({ ok = true })
end)

CreateThread(function()
	while true do
		local sleep = 700
		local playerPed = PlayerPedId()
		local playerCoords = GetEntityCoords(playerPed)
		local markerConfig = Config.Marker or {}

		for shopIndex, shop in ipairs(Config.Shops or {}) do
			local interaction = shop.interaction
			if interaction then
				local distance = #(playerCoords - interaction)
				local drawDistance = tonumber(shop.drawDistance) or 20.0

				if distance <= drawDistance then
					local shopDemoKey = getShopDemoKey(shop, shopIndex)
					if not spawnedDemoShops[shopDemoKey] then
						spawnDemoVehiclesForShop(shop)
						spawnedDemoShops[shopDemoKey] = true
					end

					sleep = 0

					if markerConfig.enabled ~= false then
						local markerScale = markerConfig.scale or vector3(0.8, 0.8, 0.8)
						local markerColor = markerConfig.color or { r = 255, g = 176, b = 46, a = 185 }

						DrawMarker(
							tonumber(markerConfig.type) or 36,
							interaction.x,
							interaction.y,
							interaction.z + 0.2,
							0.0,
							0.0,
							0.0,
							0.0,
							0.0,
							0.0,
							markerScale.x,
							markerScale.y,
							markerScale.z,
							markerColor.r,
							markerColor.g,
							markerColor.b,
							markerColor.a,
							markerConfig.bobUpAndDown == true,
							true,
							2,
							markerConfig.rotate == true,
							nil,
							nil,
							false
						)
					end

					local interactionRadius = tonumber(shop.interactionRadius) or 2.5
					if distance <= interactionRadius and not uiOpen and not vehicleEditorOpen then
						showHelpPrompt(Config.OpenPrompt or 'Press ~INPUT_CONTEXT~ to browse dealership inventory')

						if IsControlJustReleased(0, tonumber(Config.InteractionKey) or 38) then
							openShop(shop)
						end
					end
				end
			end
		end

		if uiOpen and activeShop and activeShop.interaction then
			local distanceFromShop = #(playerCoords - activeShop.interaction)
			local autoCloseDistance = tonumber(Config.AutoCloseDistance) or 9.0

			if distanceFromShop > autoCloseDistance then
				closeShop()
				notify('You stepped away from the dealership.')
			end
		end

		Wait(sleep)
	end
end)

AddEventHandler('lsrp_vehicleeditor:opened', function()
	vehicleEditorOpen = true
end)

AddEventHandler('lsrp_vehicleeditor:closed', function()
	vehicleEditorOpen = false
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	clearDemoVehicles()

	if uiOpen then
		SetNuiFocus(false, false)
	end
end)
