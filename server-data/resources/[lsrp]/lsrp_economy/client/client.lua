-- LSRP Economy System - Client Script
--
-- Tracks the local player's LS$ balance, provides exports for other resources,
-- and hosts a bank/ATM NUI for account overview and transfers.

local currentBalance = 0
local currentCash = 0
local currencySymbol = 'LS$'
local currentAccountId = nil

local uiOpen = false
local uiAccessType = nil
local uiAnchorCoords = nil
local uiAnchorLabel = nil

local INTERACT_CONTROL = 38 -- INPUT_CONTEXT (E)
local ATM_SCAN_RADIUS = 5.0
local ATM_INTERACT_DISTANCE = 1.8
local BANK_INTERACT_DISTANCE = 2.2
local UI_MAX_DISTANCE = 7.5
local INTERACTION_IDLE_WAIT_MS = 600
local INTERACTION_ACTIVE_WAIT_MS = 0

local ATM_MODELS = {
	`prop_atm_01`,
	`prop_atm_02`,
	`prop_atm_03`,
	`prop_fleeca_atm`
}

local BANK_LOCATIONS = {
	{ label = 'Legion Fleeca', coords = vector3(149.90, -1040.46, 29.37) },
	{ label = 'Hawick Fleeca', coords = vector3(314.18, -278.62, 54.17) },
	{ label = 'Burton Fleeca', coords = vector3(-351.53, -49.53, 49.04) },
	{ label = 'Rockford Fleeca', coords = vector3(-1212.98, -330.84, 37.78) },
	{ label = 'Great Ocean Fleeca', coords = vector3(-2962.58, 482.62, 15.70) },
	{ label = 'Paleto Bay Fleeca', coords = vector3(-112.21, 6469.29, 31.63) },
	{ label = 'Route 68 Fleeca', coords = vector3(1175.06, 2706.64, 38.09) },
	{ label = 'Pacific Standard', coords = vector3(246.64, 223.20, 106.29) }
}

-- Formats a non-negative integer as a comma-separated LS$ string.
local function formatCurrency(amount)
	local value = tonumber(amount) or 0
	value = math.max(0, math.floor(value))

	local formatted = tostring(value)
	while true do
		local updated, replacements = formatted:gsub('^(%-?%d+)(%d%d%d)', '%1,%2')
		formatted = updated

		if replacements == 0 then
			break
		end
	end

	return currencySymbol .. formatted
end

local function normalizePositiveWholeDollarAmount(value)
	local amount = tonumber(value)
	if not amount or amount <= 0 then
		return nil
	end

	if amount ~= math.floor(amount) then
		return nil
	end

	return math.floor(amount)
end

local function normalizeAccountId(value)
	local accountId = tonumber(value)
	if not accountId or accountId <= 0 then
		return nil
	end

	if accountId ~= math.floor(accountId) then
		return nil
	end

	return math.floor(accountId)
end

local function notify(message)
	local text = tostring(message or '')
	if text == '' then
		return
	end

	TriggerEvent('chat:addMessage', {
		args = { '^2LSRP', text }
	})
end

local function showHelpPrompt(message)
	BeginTextCommandDisplayHelp('STRING')
	AddTextComponentString(message)
	EndTextCommandDisplayHelp(0, false, true, -1)
end

local function isInteractControlJustPressed()
	return IsControlJustPressed(0, INTERACT_CONTROL)
		or IsControlJustPressed(1, INTERACT_CONTROL)
		or IsDisabledControlJustPressed(0, INTERACT_CONTROL)
		or IsDisabledControlJustPressed(1, INTERACT_CONTROL)
end

local function sendUiToast(level, message)
	if not uiOpen then
		return
	end

	SendNUIMessage({
		action = 'toast',
		level = level or 'info',
		message = tostring(message or '')
	})
end

-- Request a balance sync from the server (e.g. on resource start or respawn).
local function requestBalanceSync()
	TriggerServerEvent('lsrp_economy:server:requestSync')
end

local function closeBankingUi(silent)
	if not uiOpen then
		return
	end

	uiOpen = false
	uiAccessType = nil
	uiAnchorCoords = nil
	uiAnchorLabel = nil

	SetNuiFocus(false, false)
	SendNUIMessage({ action = 'close' })

	if silent then
		return
	end
end

local function openBankingUi(accessType, anchorCoords, anchorLabel)
	if uiOpen then
		return
	end
	
	uiOpen = true
	uiAccessType = accessType or 'bank'
	uiAnchorCoords = anchorCoords
	uiAnchorLabel = anchorLabel

	SetNuiFocus(true, true)
	SendNUIMessage({
		action = 'open',
		accessType = uiAccessType,
		locationLabel = uiAnchorLabel or (uiAccessType == 'atm' and 'ATM' or 'Bank'),
		accountId = currentAccountId,
		balance = currentBalance,
		cash = currentCash,
		formattedBalance = formatCurrency(currentBalance),
		formattedCash = formatCurrency(currentCash),
		currencySymbol = currencySymbol,
		allowTransfers = uiAccessType == 'bank'
	})
	TriggerServerEvent('lsrp_economy:server:ui:requestData')
end

local function getNearestBankInteraction(playerCoords)
	local nearest = nil
	local nearestDistance = BANK_INTERACT_DISTANCE + 0.001

	for _, bank in ipairs(BANK_LOCATIONS) do
		local distance = #(playerCoords - bank.coords)
		if distance <= BANK_INTERACT_DISTANCE and distance < nearestDistance then
			nearestDistance = distance
			nearest = {
				accessType = 'bank',
				coords = bank.coords,
				label = bank.label,
				distance = distance
			}
		end
	end

	return nearest
end

local function getNearestAtmInteraction(playerCoords)
	local nearest = nil
	local nearestDistance = ATM_INTERACT_DISTANCE + 0.001

	for _, modelHash in ipairs(ATM_MODELS) do
		local atmObject = GetClosestObjectOfType(playerCoords.x, playerCoords.y, playerCoords.z, ATM_SCAN_RADIUS, modelHash, false, false, false)

		if atmObject ~= 0 then
			local atmCoords = GetEntityCoords(atmObject)
			local distance = #(playerCoords - atmCoords)
			if distance <= ATM_INTERACT_DISTANCE and distance < nearestDistance then
				nearestDistance = distance
				nearest = {
					accessType = 'atm',
					coords = atmCoords,
					label = 'ATM',
					distance = distance
				}
			end
		end
	end

	return nearest
end

local function getNearestBankingInteraction(playerCoords)
	local nearestBank = getNearestBankInteraction(playerCoords)
	local nearestAtm = getNearestAtmInteraction(playerCoords)

	if nearestBank and nearestAtm then
		if nearestAtm.distance < nearestBank.distance then
			return nearestAtm
		end

		return nearestBank
	end

	return nearestBank or nearestAtm
end

local function tryOpenNearestBanking(accessTypeFilter, quiet)
	if uiOpen then
		return true
	end

	local playerPed = PlayerPedId()
	if playerPed == 0 or not DoesEntityExist(playerPed) then
		return false
	end

	local playerCoords = GetEntityCoords(playerPed)
	local interaction = nil

	if accessTypeFilter == 'bank' then
		interaction = getNearestBankInteraction(playerCoords)
	elseif accessTypeFilter == 'atm' then
		interaction = getNearestAtmInteraction(playerCoords)
	else
		interaction = getNearestBankingInteraction(playerCoords)
	end

	if not interaction then
		if not quiet then
			if accessTypeFilter == 'bank' then
				notify('You are not close enough to a bank counter.')
			elseif accessTypeFilter == 'atm' then
				notify('You are not close enough to an ATM.')
			else
				notify('No bank terminal nearby.')
			end
		end
		return false
	end

	openBankingUi(interaction.accessType, interaction.coords, interaction.label)
	return true
end

-- ---------------------------------------------------------------------------
-- Net events: server pushes updated balance and UI payloads
-- ---------------------------------------------------------------------------

RegisterNetEvent('lsrp_economy:client:balanceUpdated', function(balance, symbol)
	currentBalance = math.max(0, math.floor(tonumber(balance) or 0))

	if type(symbol) == 'string' and symbol ~= '' then
		currencySymbol = symbol
	end

	if uiOpen then
		SendNUIMessage({
			action = 'setBalance',
			balance = currentBalance,
			formattedBalance = formatCurrency(currentBalance),
			currencySymbol = currencySymbol
		})

		TriggerServerEvent('lsrp_economy:server:ui:requestData')
	end
end)

RegisterNetEvent('lsrp_economy:client:cashUpdated', function(cash, symbol)
	currentCash = math.max(0, math.floor(tonumber(cash) or 0))

	if type(symbol) == 'string' and symbol ~= '' then
		currencySymbol = symbol
	end

	if uiOpen then
		SendNUIMessage({
			action = 'setCash',
			cash = currentCash,
			formattedCash = formatCurrency(currentCash),
			currencySymbol = currencySymbol
		})
	end
end)

RegisterNetEvent('lsrp_economy:client:ui:data', function(payload)
	if type(payload) ~= 'table' then
		return
	end

	if payload.accountId ~= nil then
		currentAccountId = normalizeAccountId(payload.accountId)
	end

	if payload.balance ~= nil then
		currentBalance = math.max(0, math.floor(tonumber(payload.balance) or 0))
	end

	if payload.cash ~= nil then
		currentCash = math.max(0, math.floor(tonumber(payload.cash) or 0))
	end

	if type(payload.currencySymbol) == 'string' and payload.currencySymbol ~= '' then
		currencySymbol = payload.currencySymbol
	end

	if not uiOpen then
		return
	end

	SendNUIMessage({
		action = 'setData',
		accountId = currentAccountId,
		balance = currentBalance,
		cash = currentCash,
		formattedBalance = formatCurrency(currentBalance),
		formattedCash = formatCurrency(currentCash),
		currencySymbol = currencySymbol,
		transactions = type(payload.transactions) == 'table' and payload.transactions or {}
	})
end)

RegisterNetEvent('lsrp_economy:client:ui:error', function(message)
	local text = tostring(message or 'Banking services are unavailable right now.')
	sendUiToast('error', text)
	notify(text)
end)

RegisterNetEvent('lsrp_economy:client:ui:transferResult', function(ok, message)
	local text = tostring(message or '')
	if text == '' then
		return
	end

	sendUiToast(ok and 'success' or 'error', text)
	notify(text)
end)

RegisterNetEvent('lsrp_economy:client:ui:cashResult', function(ok, message)
	local text = tostring(message or '')
	if text == '' then
		return
	end

	sendUiToast(ok and 'success' or 'error', text)
	notify(text)
end)

-- ---------------------------------------------------------------------------
-- Resource lifecycle
-- ---------------------------------------------------------------------------

AddEventHandler('onClientResourceStart', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	requestBalanceSync()
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	if uiOpen then
		SetNuiFocus(false, false)
	end
end)

AddEventHandler('playerSpawned', function()
	requestBalanceSync()
end)

CreateThread(function()
	while true do
		local waitTime = INTERACTION_IDLE_WAIT_MS

		if not IsPauseMenuActive() then
			local playerPed = PlayerPedId()
			if playerPed ~= 0 and DoesEntityExist(playerPed) then
				local playerCoords = GetEntityCoords(playerPed)

				if uiOpen and uiAnchorCoords then
					local distanceFromTerminal = #(playerCoords - uiAnchorCoords)
					if distanceFromTerminal > UI_MAX_DISTANCE then
						closeBankingUi(true)
						notify('You moved away from the banking terminal.')
					else
						waitTime = 100
					end
				elseif not uiOpen then
					local interaction = getNearestBankingInteraction(playerCoords)
					if interaction then
						waitTime = INTERACTION_ACTIVE_WAIT_MS

						if interaction.accessType == 'atm' then
							showHelpPrompt('Press ~INPUT_CONTEXT~ to use the ATM')
						else
							showHelpPrompt('Press ~INPUT_CONTEXT~ to access bank services')
						end

						if isInteractControlJustPressed() then
							openBankingUi(interaction.accessType, interaction.coords, interaction.label)
						end
					end
				end
			end
		end

		Wait(waitTime)
	end
end)

-- ---------------------------------------------------------------------------
-- Commands
-- ---------------------------------------------------------------------------

RegisterCommand('bank', function()
	tryOpenNearestBanking('bank', false)
end, false)

RegisterCommand('atm', function()
	tryOpenNearestBanking('atm', false)
end, false)

-- ---------------------------------------------------------------------------
-- NUI callbacks
-- ---------------------------------------------------------------------------

RegisterNUICallback('close', function(_, cb)
	closeBankingUi(true)
	cb({ ok = true })
end)

RegisterNUICallback('requestData', function(_, cb)
	TriggerServerEvent('lsrp_economy:server:ui:requestData')
	cb({ ok = true })
end)

RegisterNUICallback('transfer', function(data, cb)
	if uiAccessType ~= 'bank' then
		sendUiToast('error', 'Transfers are only available at a bank counter.')
		cb({ ok = false, error = 'transfer_unavailable' })
		return
	end

	local targetAccountId = normalizeAccountId(data and data.targetAccountId)
	local amount = normalizePositiveWholeDollarAmount(data and data.amount)

	if not targetAccountId then
		sendUiToast('error', 'Enter a valid target account ID.')
		cb({ ok = false, error = 'invalid_target' })
		return
	end

	if currentAccountId and targetAccountId == currentAccountId then
		sendUiToast('error', 'You cannot transfer money to yourself.')
		cb({ ok = false, error = 'same_player' })
		return
	end

	if not amount then
		sendUiToast('error', 'Enter a positive whole-dollar amount.')
		cb({ ok = false, error = 'invalid_amount' })
		return
	end

	TriggerServerEvent('lsrp_economy:server:ui:transfer', targetAccountId, amount)
	cb({ ok = true })
end)

RegisterNUICallback('deposit', function(data, cb)
	local amount = normalizePositiveWholeDollarAmount(data and data.amount)

	if not amount then
		sendUiToast('error', 'Enter a positive whole-dollar amount.')
		cb({ ok = false, error = 'invalid_amount' })
		return
	end

	TriggerServerEvent('lsrp_economy:server:ui:deposit', amount)
	cb({ ok = true })
end)

RegisterNUICallback('withdraw', function(data, cb)
	local amount = normalizePositiveWholeDollarAmount(data and data.amount)

	if not amount then
		sendUiToast('error', 'Enter a positive whole-dollar amount.')
		cb({ ok = false, error = 'invalid_amount' })
		return
	end

	TriggerServerEvent('lsrp_economy:server:ui:withdraw', amount)
	cb({ ok = true })
end)

-- ---------------------------------------------------------------------------
-- Exports
-- ---------------------------------------------------------------------------

exports('getBalance', function()
	return currentBalance
end)

exports('getCash', function()
	return currentCash
end)

exports('formatCurrency', function(amount)
	if amount == nil then
		amount = currentBalance
	end

	return formatCurrency(amount)
end)
