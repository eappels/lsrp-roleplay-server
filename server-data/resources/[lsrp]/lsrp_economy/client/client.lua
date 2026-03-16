-- LSRP Economy System - Client Script
--
-- Tracks the local player's balance on the client side using a state bag
-- (ls_balance) pushed by the server. Provides two exports for other resources
-- to read the cached balance and format currency strings.
--
-- Exports:
--   getBalance()              -> number   current balance (whole dollars)
--   formatCurrency(amount)    -> string   e.g. 'LS$1,234' (nil = current balance)
--
-- Net events received:
--   lsrp_economy:client:balanceUpdated(balance, symbol) - server pushes a new value

local currentBalance = 0
local currencySymbol = 'LS$'

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

-- Request a balance sync from the server (e.g. on resource start or respawn).
local function requestBalanceSync()
	TriggerServerEvent('lsrp_economy:server:requestSync')
end

-- ---------------------------------------------------------------------------
-- Net event: server pushes updated balance + currency symbol
-- ---------------------------------------------------------------------------
RegisterNetEvent('lsrp_economy:client:balanceUpdated', function(balance, symbol)
	currentBalance = math.max(0, math.floor(tonumber(balance) or 0))

	if type(symbol) == 'string' and symbol ~= '' then
		currencySymbol = symbol
	end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	requestBalanceSync()
end)

AddEventHandler('playerSpawned', function()
	requestBalanceSync()
end)

-- ---------------------------------------------------------------------------
-- Exports
-- ---------------------------------------------------------------------------

exports('getBalance', function()
	return currentBalance
end)

exports('formatCurrency', function(amount)
	if amount == nil then
		amount = currentBalance
	end

	return formatCurrency(amount)
end)
