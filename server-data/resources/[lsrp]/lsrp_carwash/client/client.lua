local uiOpen = false
local activeLocation = nil
local washInProgress = false
local currentBalance = 0
local currentFormattedBalance = 'LS$0'
local currentWashPrice = math.max(0, math.floor(tonumber(Config.WashPrice) or 0))
local currentFormattedWashPrice = nil

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

local function notify(message, level)
	if GetResourceState('lsrp_framework') == 'started' then
		exports['lsrp_framework']:notify(tostring(message or ''), level or 'info')
		return
	end

	BeginTextCommandThefeedPost('STRING')
	AddTextComponentSubstringPlayerName(tostring(message or ''))
	EndTextCommandThefeedPostTicker(false, true)
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

local function triggerFrameworkCallback(callbackName, payload, timeoutMs)
	if GetResourceState('lsrp_framework') ~= 'started' then
		return {
			ok = false,
			error = 'framework_unavailable'
		}
	end

	local ok, response = pcall(function()
		return exports['lsrp_framework']:triggerServerCallback(callbackName, payload, timeoutMs)
	end)

	if not ok or type(response) ~= 'table' then
		return {
			ok = false,
			error = 'framework_callback_failed'
		}
	end

	return response
end

local function applySnapshot(snapshot)
	if type(snapshot) ~= 'table' then
		return
	end

	currentBalance = math.max(0, math.floor(tonumber(snapshot.balance) or currentBalance or 0))
	currentFormattedBalance = trimString(snapshot.formattedBalance) or formatFallbackCurrency(currentBalance)
	currentWashPrice = math.max(0, math.floor(tonumber(snapshot.washPrice) or currentWashPrice or 0))
	currentFormattedWashPrice = trimString(snapshot.formattedWashPrice) or formatFallbackCurrency(currentWashPrice)

	if uiOpen then
		SendNUIMessage({
			action = 'setSnapshot',
			payload = {
				balance = currentBalance,
				formattedBalance = currentFormattedBalance,
				washPrice = currentWashPrice,
				formattedWashPrice = currentFormattedWashPrice
			}
		})
	end
	end

local function refreshSnapshot(locationId)
	local response = triggerFrameworkCallback('lsrp_carwash:getSnapshot', {
		locationId = locationId
	}, 5000)

	if not response.ok or type(response.data) ~= 'table' then
		return false, response.error or 'snapshot_failed'
	end

	applySnapshot(response.data)
	return true, nil
end

local function showHelpPrompt(message)
	BeginTextCommandDisplayHelp('STRING')
	AddTextComponentSubstringPlayerName(tostring(message or ''))
	EndTextCommandDisplayHelp(0, false, true, -1)
end

local function getLocationLabel(location)
	return trimString(location and location.label) or 'Carwash'
end

local function getCurrentVehicle()
	local ped = PlayerPedId()
	if ped == 0 or not DoesEntityExist(ped) then
		return 0
	end

	local vehicle = GetVehiclePedIsIn(ped, false)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return 0
	end

	return vehicle
end

local function isPlayerDriver(vehicle)
	local ped = PlayerPedId()
	return vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped
end

local function getVehicleDisplayName(vehicle)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return 'Current Vehicle'
	end

	local displayName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
	local label = GetLabelText(displayName)
	if label and label ~= 'NULL' then
		return label
	end

	return displayName or 'Current Vehicle'
end

local function closeCarwashUi()
	if not uiOpen then
		return
	end

	uiOpen = false
	activeLocation = nil
	SetNuiFocus(false, false)
	if type(SetNuiFocusKeepInput) == 'function' then
		SetNuiFocusKeepInput(false)
	end

	SendNUIMessage({ action = 'close' })
end

local function openCarwashUi(location)
	local vehicle = getCurrentVehicle()
	if vehicle == 0 then
		notify('You need to be inside a vehicle.', 'error')
		return
	end

	if not isPlayerDriver(vehicle) then
		notify('You need to be in the driver seat to use the carwash.', 'error')
		return
	end

	if uiOpen then
		closeCarwashUi()
	end

	uiOpen = true
	activeLocation = location
	SetNuiFocus(true, true)
	if type(SetNuiFocusKeepInput) == 'function' then
		SetNuiFocusKeepInput(false)
	end

	SendNUIMessage({
		action = 'open',
		payload = {
			locationLabel = getLocationLabel(location),
			vehicleLabel = getVehicleDisplayName(vehicle),
			washDurationMs = math.max(1000, math.floor(tonumber(Config.WashDurationMs) or 3500)),
			balance = currentBalance,
			formattedBalance = currentFormattedBalance,
			washPrice = currentWashPrice,
			formattedWashPrice = currentFormattedWashPrice or formatFallbackCurrency(currentWashPrice)
		}
	})

	CreateThread(function()
		local ok, errorCode = refreshSnapshot(location.id)
		if not ok then
			notify(('Carwash balance refresh failed: %s'):format(tostring(errorCode)), 'error')
		end
	end)
end

local function canUseLocation(location)
	if type(location) ~= 'table' or type(location.coords) ~= 'vector3' then
		return false
	end

	local vehicle = getCurrentVehicle()
	if vehicle == 0 then
		return false
	end

	local vehicleCoords = GetEntityCoords(vehicle)
	local promptDistance = tonumber(Config.PromptDistance) or 3.0
	return #(vehicleCoords - location.coords) <= promptDistance
end

local function washVehicleAtActiveLocation()
	if washInProgress then
		return false, 'wash_in_progress'
	end

	local location = activeLocation
	if not canUseLocation(location) then
		return false, 'vehicle_not_in_bay'
	end

	local vehicle = getCurrentVehicle()
	if vehicle == 0 then
		return false, 'no_vehicle'
	end

	washInProgress = true
	FreezeEntityPosition(vehicle, true)

	local durationMs = math.max(1000, math.floor(tonumber(Config.WashDurationMs) or 3500))
	CreateThread(function()
		Wait(durationMs)
		if DoesEntityExist(vehicle) then
			SetVehicleDirtLevel(vehicle, 0.0)
			WashDecalsFromVehicle(vehicle, 1.0)
			SetVehicleUndriveable(vehicle, false)
			FreezeEntityPosition(vehicle, false)
		end

		washInProgress = false
		notify('Vehicle washed.', 'success')
		closeCarwashUi()
	end)

	return true, nil
end

RegisterNUICallback('close', function(_, cb)
	closeCarwashUi()
	cb({ ok = true })
end)

RegisterNUICallback('washVehicle', function(_, cb)
	local locationId = trimString(activeLocation and activeLocation.id)
	local response = triggerFrameworkCallback('lsrp_carwash:washVehicle', {
		locationId = locationId
	}, 5000)

	if type(response.data) == 'table' then
		applySnapshot(response.data)
	end

	if not response.ok then
		local errorCode = response.error
		if errorCode == 'not_in_bay' or errorCode == 'vehicle_not_in_bay' then
			notify('Move the vehicle into the carwash bay first.', 'error')
		elseif errorCode == 'no_vehicle' then
			notify('You are not inside a vehicle.', 'error')
		elseif errorCode == 'wash_in_progress' then
			notify('A wash is already in progress.', 'error')
		elseif errorCode == 'insufficient_funds' then
			notify(('Not enough LS$. Current balance: %s'):format(currentFormattedBalance), 'error')
		elseif errorCode == 'framework_unavailable' then
			notify('Carwash payment services are unavailable right now.', 'error')
		else
			notify('Could not start the wash.', 'error')
		end

		cb({ ok = false, error = errorCode, balance = currentBalance })
		return
	end

	local ok, errorCode = washVehicleAtActiveLocation()
	if not ok then
		cb({ ok = false, error = errorCode })
		return
	end

	cb({
		ok = true,
		data = {
			started = true,
			washDurationMs = math.max(1000, math.floor(tonumber(Config.WashDurationMs) or 3500)),
			balance = currentBalance,
			formattedBalance = currentFormattedBalance,
			washPrice = currentWashPrice,
			formattedWashPrice = currentFormattedWashPrice
		}
	})
end)

CreateThread(function()
	for _, location in ipairs(Config.Locations or {}) do
		local blipCfg = location.blip
		if type(blipCfg) == 'table' and blipCfg.enabled ~= false and type(location.coords) == 'vector3' then
			local blip = AddBlipForCoord(location.coords.x, location.coords.y, location.coords.z)
			SetBlipSprite(blip, tonumber(blipCfg.sprite) or 100)
			SetBlipDisplay(blip, 4)
			SetBlipScale(blip, tonumber(blipCfg.scale) or 0.8)
			SetBlipColour(blip, tonumber(blipCfg.color) or 2)
			SetBlipAsShortRange(blip, true)
			BeginTextCommandSetBlipName('STRING')
			AddTextComponentSubstringPlayerName(trimString(blipCfg.label) or getLocationLabel(location))
			EndTextCommandSetBlipName(blip)
		end
	end

	while true do
		local waitMs = 800
		local vehicle = getCurrentVehicle()
		if vehicle ~= 0 then
			local vehicleCoords = GetEntityCoords(vehicle)
			for _, location in ipairs(Config.Locations or {}) do
				if type(location.coords) == 'vector3' then
					local distance = #(vehicleCoords - location.coords)
					local markerDistance = tonumber(Config.MarkerDistance) or 18.0
					local promptDistance = tonumber(Config.PromptDistance) or 3.0
					local markerCfg = location.marker or {}
					if distance <= markerDistance then
						waitMs = 0
						if markerCfg.enabled ~= false then
							local scale = markerCfg.scale or vector3(1.0, 1.0, 1.0)
							local color = markerCfg.color or { r = 86, g = 195, b = 138, a = 190 }
							DrawMarker(
								tonumber(markerCfg.type) or 36,
								location.coords.x,
								location.coords.y,
								location.coords.z,
								0.0, 0.0, 0.0,
								0.0, 0.0, 0.0,
								scale.x, scale.y, scale.z,
								color.r or 86, color.g or 195, color.b or 138, color.a or 190,
								false, true, 2, nil, nil, false
							)
						end
					end

					if distance <= promptDistance and isPlayerDriver(vehicle) and not washInProgress then
						showHelpPrompt(Config.PromptText or 'Press ~INPUT_CONTEXT~ to use the carwash')
						if IsControlJustPressed(0, tonumber(Config.OpenKey) or 38) then
							openCarwashUi(location)
						end
					elseif uiOpen and activeLocation == location and distance > (tonumber(Config.AutoCloseDistance) or 8.0) then
						closeCarwashUi()
					end
				end
			end
		elseif uiOpen and not washInProgress then
			closeCarwashUi()
		end

		Wait(waitMs)
	end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	closeCarwashUi()
end)