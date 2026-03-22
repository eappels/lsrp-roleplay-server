local uiOpen = false
local uiMode = nil
local currentLocationFilter = nil
local currentApartment = nil
local cachedOwnedApartments = {}
local cachedAvailableApartments = {}
local pendingListAction = nil
local housingBlips = {}
local nuiReady = false
local pendingUiOpenRequest = nil

local function isHousingNuiEnabled()
	return Config and Config.EnableNui == true
end

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

local function normalizeApartmentNumber(value)
	local trimmed = trimString(value)
	if not trimmed then
		return nil
	end

	local normalized = string.upper(trimmed)
	if #normalized > 16 or normalized:find('[^%w%-]') then
		return nil
	end

	return normalized
end

local function toVector3(point)
	if type(point) ~= 'table' then
		return nil
	end

	return vector3(tonumber(point.x) or 0.0, tonumber(point.y) or 0.0, tonumber(point.z) or 0.0)
end

local function getHeading(point)
	if type(point) ~= 'table' then
		return 0.0
	end

	return tonumber(point.w) or 0.0
end

local function getLocation(index)
	index = tonumber(index)
	if not index or index <= 0 or index ~= math.floor(index) then
		return nil
	end

	local locations = Config and Config.Locations or {}
	return locations[index]
end

local function createHousingBlips()
	for _, blip in ipairs(housingBlips) do
		if DoesBlipExist(blip) then
			RemoveBlip(blip)
		end
	end
	housingBlips = {}

	local blipConfig = Config and Config.Blip or {}
	if blipConfig.enabled == false then
		return
	end

	for _, location in ipairs(Config and Config.Locations or {}) do
		local point = location.catalog or location.entry
		local coords = toVector3(point)
		if coords then
			local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
			SetBlipSprite(blip, math.floor(tonumber(blipConfig.sprite) or 40))
			SetBlipColour(blip, math.floor(tonumber(blipConfig.color) or 3))
			SetBlipScale(blip, tonumber(blipConfig.scale) or 0.8)
			SetBlipAsShortRange(blip, blipConfig.shortRange ~= false)
			BeginTextCommandSetBlipName('STRING')
			AddTextComponentString(tostring(location.label or blipConfig.label or 'Apartments'))
			EndTextCommandSetBlipName(blip)
			housingBlips[#housingBlips + 1] = blip
		end
	end
end

local function notify(message)
	local text = tostring(message or '')
	if text == '' then
		return
	end

	TriggerEvent('chat:addMessage', {
		args = { '^3LSRP', text }
	})
end

local function notifyLines(lines)
	for _, line in ipairs(type(lines) == 'table' and lines or {}) do
		notify(line)
	end
end

local function filterApartmentsByLocation(apartments, locationIndex)
	if not locationIndex then
		return apartments
	end

	local filtered = {}
	for _, apartment in ipairs(type(apartments) == 'table' and apartments or {}) do
		if tonumber(apartment.location_index) == tonumber(locationIndex) then
			filtered[#filtered + 1] = apartment
		end
	end

	return filtered
end

local function formatApartmentLine(apartment, includeRentDue)
	local apartmentNumber = tostring(apartment.apartment_number or '?')
	local shorthand = apartmentNumber:gsub('%-', ''):match('(%d%d%d)$')
	local locationLabel = tostring(apartment.location_label or ('Location ' .. tostring(apartment.location_index or '?')))
	local price = ('LS$%s'):format(tostring(math.floor(tonumber(apartment.price) or 0)))
	local heading = shorthand and ('[%d] %s'):format(tonumber(shorthand) or 0, apartmentNumber) or apartmentNumber
	if includeRentDue then
		return ('%s | %s | rent %s | due %s'):format(heading, locationLabel, price, tostring(apartment.rent_due or 'not set'))
	end

	return ('%s | %s | rent %s'):format(heading, locationLabel, price)
end

local function printApartmentList(title, apartments, includeRentDue, footer)
	local lines = { title }
	local list = type(apartments) == 'table' and apartments or {}
	if #list == 0 then
		lines[#lines + 1] = 'None found.'
	else
		for index, apartment in ipairs(list) do
			if index > 8 then
				lines[#lines + 1] = ('...and %d more.'):format(#list - 8)
				break
			end
			lines[#lines + 1] = formatApartmentLine(apartment, includeRentDue)
		end
	end

	if footer then
		lines[#lines + 1] = footer
	end

	notifyLines(lines)
end

local function findOwnedApartmentByNumber(apartmentNumber)
	local normalizedApartmentNumber = normalizeApartmentNumber(apartmentNumber)
	if not normalizedApartmentNumber then
		return nil
	end

	for _, apartment in ipairs(cachedOwnedApartments) do
		if apartment.apartment_number == normalizedApartmentNumber then
			return apartment
		end
	end

	return nil
end

local function findOwnedApartmentsForLocation(locationIndex)
	return filterApartmentsByLocation(cachedOwnedApartments, locationIndex)
end

local function findAvailableApartmentsForLocation(locationIndex)
	return filterApartmentsByLocation(cachedAvailableApartments, locationIndex)
end

local function getCommandName(key, fallback)
	return (Config and Config.Commands and Config.Commands[key]) or fallback
end

local function printHousingHelp(locationIndex)
	local location = getLocation(locationIndex)
	local locationLabel = location and tostring(location.label or ('Location ' .. tostring(locationIndex))) or 'this building'
	notifyLines({
		('Housing commands for %s:'):format(locationLabel),
		('/%s <apartment_number> - enter an owned apartment'):format(getCommandName('enter', 'houseenter')),
		('/%s <apartment_number> - rent an available apartment'):format(getCommandName('rent', 'houserent')),
		('/payrent <apartment_number> - pay apartment rent'),
		('/%s - list your apartments'):format(getCommandName('owned', 'housingowned')),
		('/%s - list available apartments'):format(getCommandName('available', 'housingavailable'))
	})
end

local function printManagementSummary(locationIndex)
	local location = getLocation(locationIndex)
	local ownedAtLocation = filterApartmentsByLocation(cachedOwnedApartments, locationIndex)
	local availableAtLocation = filterApartmentsByLocation(cachedAvailableApartments, locationIndex)
	local locationTitle = location and tostring(location.label or ('Location ' .. tostring(locationIndex))) or 'Housing'

	printApartmentList(
		('Your apartments at %s:'):format(locationTitle),
		ownedAtLocation,
		true,
		('/%s <apartment_number> to enter. /payrent <apartment_number> to pay rent.'):format(getCommandName('enter', 'houseenter'))
	)
	printApartmentList(
		('Available apartments at %s:'):format(locationTitle),
		availableAtLocation,
		false,
		('/%s <apartment_number> to rent one.'):format(getCommandName('rent', 'houserent'))
	)
end

local function handleNonNuiPrompt(mode, locationIndex)
	if mode == 'keypad' then
		local ownedAtLocation = findOwnedApartmentsForLocation(locationIndex)
		if #ownedAtLocation == 1 then
			TriggerServerEvent('lsrp_housing:attemptEnter', ownedAtLocation[1].apartment_number, locationIndex)
			return
		end

		if #ownedAtLocation > 1 then
			printApartmentList(
				'Your apartments at this building:',
				ownedAtLocation,
				true,
				('/%s <apartment_number> to enter one.'):format(getCommandName('enter', 'houseenter'))
			)
			return
		end

		notify('You do not own an apartment at this building.')
		printHousingHelp(locationIndex)
		return
	end

	if mode == 'catalog' then
		printManagementSummary(locationIndex)
		TriggerServerEvent('lsrp_housing:requestOwned')
		TriggerServerEvent('lsrp_housing:requestAvailable')
		return
	end

	if mode == 'kiosk' then
		printManagementSummary(locationIndex)
		TriggerServerEvent('lsrp_housing:requestOwned')
		TriggerServerEvent('lsrp_housing:requestAvailable')
		return
	end
end

local function refreshAndPrintAvailable(locationIndex)
	pendingListAction = { type = 'available', locationIndex = locationIndex }
	TriggerServerEvent('lsrp_housing:requestAvailable')
end

local function refreshAndPrintOwned(locationIndex)
	pendingListAction = { type = 'owned', locationIndex = locationIndex }
	TriggerServerEvent('lsrp_housing:requestOwned')
end

local function showHelpText(message)
	BeginTextCommandDisplayHelp('STRING')
	AddTextComponentSubstringPlayerName(message)
	EndTextCommandDisplayHelp(0, false, true, -1)
end

local function isInteractControlJustPressed()
	local control = tonumber(Config and Config.InteractControl) or 38
	return IsControlJustPressed(0, control)
		or IsControlJustPressed(1, control)
		or IsDisabledControlJustPressed(0, control)
		or IsDisabledControlJustPressed(1, control)
end

local function drawInteractionMarker(point)
	if type(point) ~= 'table' then
		return
	end

	local markerType = tonumber(Config and Config.MarkerType) or 1
	local scale = Config and Config.MarkerScale or {}
	local color = Config and Config.MarkerColor or {}

	DrawMarker(
		markerType,
		tonumber(point.x) or 0.0,
		tonumber(point.y) or 0.0,
		(tonumber(point.z) or 0.0) - 0.95,
		0.0,
		0.0,
		0.0,
		0.0,
		0.0,
		0.0,
		tonumber(scale.x) or 0.35,
		tonumber(scale.y) or 0.35,
		tonumber(scale.z) or 0.2,
		tonumber(color.r) or 88,
		tonumber(color.g) or 173,
		tonumber(color.b) or 255,
		tonumber(color.a) or 160,
		false,
		true,
		2,
		false,
		nil,
		nil,
		false
	)
end

local function sendUiDataForMode()
	if not uiOpen then
		return
	end

	if uiMode == 'catalog' and not (Config and Config.CombineCatalogAndKiosk == true) then
		SendNUIMessage({ action = 'populateCatalog', items = cachedAvailableApartments })
	elseif uiMode == 'kiosk' or (uiMode == 'catalog' and Config and Config.CombineCatalogAndKiosk == true) then
		SendNUIMessage({ action = 'populateOwned', items = cachedOwnedApartments })
		SendNUIMessage({ action = 'populateAvailable', items = cachedAvailableApartments })
	end
end

local function dispatchUiOpen(effectiveMode)
	if effectiveMode == 'keypad' then
		SendNUIMessage({ action = 'openKeypad' })
	elseif effectiveMode == 'catalog' then
		SendNUIMessage({ action = 'openCatalog' })
		SendNUIMessage({ action = 'populateCatalog', items = cachedAvailableApartments })
	elseif effectiveMode == 'kiosk' then
		SendNUIMessage({ action = 'openKiosk' })
		SendNUIMessage({ action = 'populateOwned', items = cachedOwnedApartments })
		SendNUIMessage({ action = 'populateAvailable', items = cachedAvailableApartments })
	end
end

local function flushPendingUiOpen()
	if not uiOpen or not isHousingNuiEnabled() then
		pendingUiOpenRequest = nil
		return
	end

	if not nuiReady then
		return
	end

	local effectiveMode = pendingUiOpenRequest and pendingUiOpenRequest.mode or uiMode
	if not effectiveMode then
		return
	end

	SendNUIMessage({ action = 'closeAll' })
	dispatchUiOpen(effectiveMode)
	sendUiDataForMode()
	pendingUiOpenRequest = nil
end

local function closeUi()
	if not isHousingNuiEnabled() then
		uiOpen = false
		uiMode = nil
		currentLocationFilter = nil
		return
	end

	if not uiOpen then
		return
	end

	uiOpen = false
	uiMode = nil
	currentLocationFilter = nil
	pendingUiOpenRequest = nil
	SetNuiFocus(false, false)
	SendNUIMessage({ action = 'closeAll' })
end

local function openUi(mode, locationIndex)
	if not isHousingNuiEnabled() then
		handleNonNuiPrompt(mode, locationIndex)
		return
	end

	local effectiveMode = mode
	if mode == 'catalog' and Config and Config.CombineCatalogAndKiosk == true then
		effectiveMode = 'kiosk'
	end

	uiOpen = true
	uiMode = effectiveMode
	currentLocationFilter = locationIndex
	pendingUiOpenRequest = { mode = effectiveMode, locationIndex = locationIndex }
	SetNuiFocus(true, true)
	flushPendingUiOpen()

	SetTimeout(300, function()
		if not uiOpen or uiMode ~= effectiveMode then
			return
		end

		flushPendingUiOpen()
	end)

	if effectiveMode == 'catalog' then
		TriggerServerEvent('lsrp_housing:requestAvailable')
	elseif effectiveMode == 'kiosk' then
		TriggerServerEvent('lsrp_housing:requestOwned')
		TriggerServerEvent('lsrp_housing:requestAvailable')
	end
end

local function teleportPlayer(point)
	local coords = toVector3(point)
	if not coords then
		return false
	end

	local playerPed = PlayerPedId()
	if playerPed == 0 or not DoesEntityExist(playerPed) then
		return false
	end

	DoScreenFadeOut(0)
	while not IsScreenFadedOut() do
		Wait(0)
	end

	SetEntityCoordsNoOffset(playerPed, coords.x, coords.y, coords.z, false, false, false)
	SetEntityHeading(playerPed, getHeading(point))
	Wait(150)
	DoScreenFadeIn(250)
	return true
end

local function getInteriorExitPoints(location)
	local exitPoints = {}
	if type(location) ~= 'table' then
		return exitPoints
	end

	local function appendUnique(point)
		if type(point) ~= 'table' then
			return
		end

		local coords = toVector3(point)
		if not coords then
			return
		end

		for _, existingPoint in ipairs(exitPoints) do
			local existingCoords = toVector3(existingPoint)
			if existingCoords and #(coords - existingCoords) < 0.25 then
				return
			end
		end

		exitPoints[#exitPoints + 1] = point
	end

	appendUnique(location.interiorExit)
	appendUnique(location.interiorSpawn)

	return exitPoints
end

local function isPlayerInsideApartmentShell(playerCoords, location)
	if type(location) ~= 'table' then
		return false
	end

	if type(location.interiorExit) == 'table' then
		return false
	end

	local anchorPoint = toVector3(location.interiorSpawn) or toVector3(location.interiorExit)
	if not anchorPoint or not playerCoords then
		return false
	end

	local fallbackRadius = tonumber(Config and Config.InteriorExitFallbackRadius) or 12.0
	if fallbackRadius < 1.0 then
		fallbackRadius = 12.0
	end

	return #(playerCoords - anchorPoint) <= fallbackRadius
end

local function findInteriorLocationByCoords(playerCoords)
	if not playerCoords then
		return nil, nil
	end

	local markerDistance = tonumber(Config and Config.MarkerDistance) or 15.0
	for index, location in ipairs(Config and Config.Locations or {}) do
		for _, exitPoint in ipairs(getInteriorExitPoints(location)) do
			local exitCoords = toVector3(exitPoint)
			if exitCoords and #(playerCoords - exitCoords) <= markerDistance then
				return index, location
			end
		end

		if isPlayerInsideApartmentShell(playerCoords, location) then
			return index, location
		end
	end

	return nil, nil
end

local function enterApartment(apartment)
	if type(apartment) ~= 'table' then
		return
	end

	local location = getLocation(apartment.location_index)
	if not location or type(location.interiorSpawn) ~= 'table' then
		notify('That apartment interior is not configured.')
		return
	end

	closeUi()
	currentApartment = apartment
	TriggerServerEvent('lsrp_housing:setBucket', apartment.bucket)
	teleportPlayer(location.interiorSpawn)
end

local function leaveApartment(locationIndexOverride)
	local locationIndex = locationIndexOverride
	if not locationIndex and type(currentApartment) == 'table' then
		locationIndex = currentApartment.location_index
	end

	if not locationIndex then
		return
	end

	local location = getLocation(locationIndex)
	local destination = location and (location.exteriorSpawn or location.entry) or nil
	TriggerServerEvent('lsrp_housing:setBucket', 0)
	if destination then
		local exteriorDestination = {
			x = destination.x,
			y = destination.y,
			z = destination.z,
			w = 113.82
		}
		teleportPlayer(exteriorDestination)
	end
	currentApartment = nil
end

RegisterNetEvent('lsrp_housing:ownedList', function(apartments)
	cachedOwnedApartments = type(apartments) == 'table' and apartments or {}
	if pendingListAction and pendingListAction.type == 'owned' then
		local locationIndex = pendingListAction.locationIndex
		if Config and Config.CombineCatalogAndKiosk == true then
			printManagementSummary(locationIndex)
		else
			local location = getLocation(locationIndex)
			printApartmentList(
				location and ('Your apartments at %s:'):format(tostring(location.label or ('Location ' .. tostring(locationIndex)))) or 'Your apartments:',
				filterApartmentsByLocation(cachedOwnedApartments, locationIndex),
				true,
				('/%s <apartment_number> to enter. /payrent <apartment_number> to pay rent.'):format(getCommandName('enter', 'houseenter'))
			)
		end
		pendingListAction = nil
	end
	if uiOpen and isHousingNuiEnabled() then
		SendNUIMessage({ action = 'populateOwned', items = cachedOwnedApartments })
	end
end)

RegisterNetEvent('lsrp_housing:availableList', function(apartments)
	cachedAvailableApartments = type(apartments) == 'table' and apartments or {}
	if pendingListAction and pendingListAction.type == 'available' then
		local locationIndex = pendingListAction.locationIndex
		if Config and Config.CombineCatalogAndKiosk == true then
			printManagementSummary(locationIndex)
		else
			local location = getLocation(locationIndex)
			printApartmentList(
				location and ('Available apartments at %s:'):format(tostring(location.label or ('Location ' .. tostring(locationIndex)))) or 'Available apartments:',
				filterApartmentsByLocation(cachedAvailableApartments, locationIndex),
				false,
				('/%s <apartment_number> to rent one.'):format(getCommandName('rent', 'houserent'))
			)
		end
		pendingListAction = nil
	end
	if uiOpen and isHousingNuiEnabled() then
		SendNUIMessage({ action = 'populateAvailable', items = cachedAvailableApartments })
		if uiMode == 'catalog' then
			SendNUIMessage({ action = 'populateCatalog', items = cachedAvailableApartments })
		end
	end
end)

RegisterNetEvent('lsrp_housing:rentResult', function(success, message)
	local text = tostring(message or '')
	if text ~= '' then
		notify(text)
	end

	if uiOpen and isHousingNuiEnabled() then
		SendNUIMessage({
			action = 'toast',
			success = success == true,
			message = text
		})
		if uiMode == 'catalog' or uiMode == 'kiosk' then
			TriggerServerEvent('lsrp_housing:requestAvailable')
			TriggerServerEvent('lsrp_housing:requestOwned')
		end
	end
end)

RegisterNetEvent('lsrp_housing:enterResult', function(success, message, apartment)
	if not success then
		notify(message or 'You could not enter that apartment.')
		if uiOpen and isHousingNuiEnabled() then
			SendNUIMessage({
				action = 'toast',
				success = false,
				message = tostring(message or '')
			})
		end
		return
	end

	if type(apartment) ~= 'table' then
		notify('That apartment data is invalid.')
		return
	end

	enterApartment(apartment)
end)

RegisterNUICallback('close', function(_, cb)
	closeUi()
	cb({ ok = true })
end)

RegisterNUICallback('closeKeypad', function(_, cb)
	closeUi()
	cb({ ok = true })
end)

RegisterNUICallback('closeCatalog', function(_, cb)
	closeUi()
	cb({ ok = true })
end)

RegisterNUICallback('closeKiosk', function(_, cb)
	closeUi()
	cb({ ok = true })
end)

RegisterNUICallback('enterApartment', function(data, cb)
	local apartmentNumber = normalizeApartmentNumber(data and data.apartment)
	if not apartmentNumber then
		cb({ ok = false, error = 'invalid_apartment' })
		return
	end

	TriggerServerEvent('lsrp_housing:attemptEnter', apartmentNumber, currentLocationFilter)
	cb({ ok = true })
end)

RegisterNUICallback('rentApartment', function(data, cb)
	local apartmentNumber = normalizeApartmentNumber(data and data.apartment)
	local offeredPrice = tonumber(data and data.price)
	if not apartmentNumber then
		cb({ ok = false, error = 'invalid_apartment' })
		return
	end

	TriggerServerEvent('lsrp_housing:rentApartment', apartmentNumber, offeredPrice)
	cb({ ok = true })
end)

RegisterNUICallback('payRent', function(data, cb)
	local apartmentNumber = normalizeApartmentNumber(data and data.apartment)
	if not apartmentNumber then
		cb({ ok = false, error = 'invalid_apartment' })
		return
	end

	TriggerServerEvent('lsrp_housing:payRent', apartmentNumber)
	cb({ ok = true })
end)

RegisterNUICallback('requestAvailable', function(_, cb)
	TriggerServerEvent('lsrp_housing:requestAvailable')
	cb({ ok = true })
end)

RegisterNUICallback('requestOwned', function(_, cb)
	TriggerServerEvent('lsrp_housing:requestOwned')
	cb({ ok = true })
end)

RegisterNUICallback('uiReady', function(_, cb)
	nuiReady = true
	flushPendingUiOpen()
	cb({ ok = true })
end)

RegisterCommand((Config and Config.Commands and Config.Commands.keypad) or 'housing', function()
	if isHousingNuiEnabled() then
		openUi('keypad', nil)
		return
	end

	refreshAndPrintOwned(nil)
end, false)

RegisterCommand((Config and Config.Commands and Config.Commands.catalog) or 'housingcatalog', function()
	if isHousingNuiEnabled() then
		openUi('catalog', nil)
		return
	end

	if Config and Config.CombineCatalogAndKiosk == true then
		refreshAndPrintOwned(nil)
	else
		refreshAndPrintAvailable(nil)
	end
end, false)

RegisterCommand((Config and Config.Commands and Config.Commands.kiosk) or 'housingkiosk', function()
	if isHousingNuiEnabled() then
		openUi('kiosk', nil)
		return
	end

	refreshAndPrintOwned(nil)
end, false)

RegisterCommand(getCommandName('available', 'housingavailable'), function(_, args)
	local locationIndex = tonumber(args[1])
	refreshAndPrintAvailable(locationIndex)
end, false)

RegisterCommand(getCommandName('owned', 'housingowned'), function(_, args)
	local locationIndex = tonumber(args[1])
	refreshAndPrintOwned(locationIndex)
end, false)

RegisterCommand(getCommandName('enter', 'houseenter'), function(_, args)
	local apartmentNumber = normalizeApartmentNumber(args[1])
	if not apartmentNumber then
		notify(('Usage: /%s <apartment_number>'):format(getCommandName('enter', 'houseenter')))
		return
	end

	local ownedApartment = findOwnedApartmentByNumber(apartmentNumber)
	local locationIndex = ownedApartment and ownedApartment.location_index or nil
	TriggerServerEvent('lsrp_housing:attemptEnter', apartmentNumber, locationIndex)
end, false)

RegisterCommand(getCommandName('rent', 'houserent'), function(_, args)
	local apartmentNumber = normalizeApartmentNumber(args[1])
	if not apartmentNumber then
		notify(('Usage: /%s <apartment_number>'):format(getCommandName('rent', 'houserent')))
		return
	end

	TriggerServerEvent('lsrp_housing:rentApartment', apartmentNumber)
end, false)

RegisterCommand(getCommandName('help', 'housinghelp'), function(_, args)
	printHousingHelp(tonumber(args[1]))
end, false)

RegisterCommand((Config and Config.Commands and Config.Commands.leave) or 'leaveapartment', function()
	leaveApartment()
end, false)

local function forceHousingUiClosed()
	uiOpen = false
	uiMode = nil
	currentLocationFilter = nil
	pendingUiOpenRequest = nil
	SetNuiFocus(false, false)
	if isHousingNuiEnabled() then
		SendNUIMessage({ action = 'closeAll' })
	end
end

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	if currentApartment then
		TriggerServerEvent('lsrp_housing:setBucket', 0)
		currentApartment = nil
	end
	nuiReady = false

	for _, blip in ipairs(housingBlips) do
		if DoesBlipExist(blip) then
			RemoveBlip(blip)
		end
	end
	housingBlips = {}

	forceHousingUiClosed()
end)

AddEventHandler('onClientResourceStart', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	nuiReady = false
	forceHousingUiClosed()
	if IsScreenFadedOut() or IsScreenFadingOut() then
		DoScreenFadeIn(0)
	end
	createHousingBlips()
	TriggerServerEvent('lsrp_housing:setBucket', 0)
	currentApartment = nil
	TriggerServerEvent('lsrp_housing:requestOwned')
	TriggerServerEvent('lsrp_housing:requestAvailable')
	TriggerEvent('chat:addSuggestion', ('/%s'):format(getCommandName('available', 'housingavailable')), 'List available apartments', {
		{ name = 'location_index', help = 'Optional building location index' }
	})
	TriggerEvent('chat:addSuggestion', ('/%s'):format(getCommandName('owned', 'housingowned')), 'List your apartments', {
		{ name = 'location_index', help = 'Optional building location index' }
	})
	TriggerEvent('chat:addSuggestion', ('/%s'):format(getCommandName('enter', 'houseenter')), 'Enter one of your apartments', {
		{ name = 'apartment_number', help = 'Apartment number, e.g. 1001 or 1' }
	})
	TriggerEvent('chat:addSuggestion', ('/%s'):format(getCommandName('rent', 'houserent')), 'Rent an available apartment', {
		{ name = 'apartment_number', help = 'Apartment number, e.g. 1001 or 1' }
	})
	TriggerEvent('chat:addSuggestion', '/payrent', 'Pay apartment rent', {
		{ name = 'apartment_number', help = 'Apartment number, e.g. 1001 or 1' }
	})
end)

CreateThread(function()
	forceHousingUiClosed()
	if IsScreenFadedOut() or IsScreenFadingOut() then
		DoScreenFadeIn(0)
	end
	TriggerServerEvent('lsrp_housing:requestOwned')
	TriggerServerEvent('lsrp_housing:requestAvailable')

	while true do
		local waitMs = 750
		local playerPed = PlayerPedId()
		local playerCoords = GetEntityCoords(playerPed)

		if uiOpen and IsControlJustPressed(0, 200) then
			closeUi()
		end

		local activeApartment = currentApartment
		local activeLocation = activeApartment and getLocation(activeApartment.location_index) or nil
		if not activeLocation then
			local inferredLocationIndex = nil
			inferredLocationIndex, activeLocation = findInteriorLocationByCoords(playerCoords)
			if inferredLocationIndex and activeLocation then
				activeApartment = { location_index = inferredLocationIndex }
			end
		end

		if activeApartment and activeLocation then
			local promptDistance = tonumber(Config and Config.PromptDistance) or 1.6
			local markerDistance = tonumber(Config and Config.MarkerDistance) or 15.0
			local nearestExitDistance = nil
			for _, exitPoint in ipairs(getInteriorExitPoints(activeLocation)) do
				local exitCoords = toVector3(exitPoint)
				if exitCoords then
					local distance = #(playerCoords - exitCoords)
					if distance <= markerDistance then
						waitMs = 0
						drawInteractionMarker(exitPoint)
					end
					if distance <= promptDistance and (not nearestExitDistance or distance < nearestExitDistance) then
						nearestExitDistance = distance
					end
				end
			end

			if nearestExitDistance then
				showHelpText((Config and Config.Text and Config.Text.exitPrompt) or 'Press ~INPUT_CONTEXT~ to leave your apartment')
				if isInteractControlJustPressed() then
					leaveApartment(activeApartment.location_index)
				end
			elseif isPlayerInsideApartmentShell(playerCoords, activeLocation) then
				waitMs = 0
				showHelpText((Config and Config.Text and Config.Text.exitFallbackPrompt) or 'Press ~INPUT_CONTEXT~ to leave the apartment')
				if isInteractControlJustPressed() then
					leaveApartment(activeApartment.location_index)
				end
			end
		else
			for index, location in ipairs(Config and Config.Locations or {}) do
				local promptDistance = tonumber(Config and Config.PromptDistance) or 1.6
				local markerDistance = tonumber(Config and Config.MarkerDistance) or 15.0

				local points = {
					{ key = 'entry', prompt = (Config and Config.Text and Config.Text.entryPrompt) or 'Press ~INPUT_CONTEXT~ to access the apartment keypad', mode = 'keypad' },
					{ key = 'catalog', prompt = (Config and Config.Text and Config.Text.catalogPrompt) or 'Press ~INPUT_CONTEXT~ to manage apartments', mode = 'catalog' }
				}

				if Config and Config.CombineCatalogAndKiosk ~= true then
					points[#points + 1] = { key = 'kiosk', prompt = (Config and Config.Text and Config.Text.kioskPrompt) or 'Press ~INPUT_CONTEXT~ to manage rent', mode = 'kiosk' }
				end

				for _, pointData in ipairs(points) do
					local point = location[pointData.key]
					local pointCoords = toVector3(point)
					if pointCoords then
						local distance = #(playerCoords - pointCoords)
						if distance <= markerDistance then
							waitMs = math.min(waitMs, 0)
							drawInteractionMarker(point)
						end
						if distance <= promptDistance then
							waitMs = 0
							showHelpText(pointData.prompt)
							if isInteractControlJustPressed() then
								openUi(pointData.mode, index)
							end
						end
					end
				end
			end
		end

		Wait(waitMs)
	end
end)