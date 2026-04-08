local function notify(message, level)
	local text = tostring(message or '')
	if text == '' then
		return
	end

	if level == 'error' then
		text = ('~r~%s'):format(text)
	elseif level == 'success' then
		text = ('~g~%s'):format(text)
	elseif level == 'warning' then
		text = ('~y~%s'):format(text)
	end

	BeginTextCommandThefeedPost('STRING')
	AddTextComponentSubstringPlayerName(text)
	EndTextCommandThefeedPostTicker(false, true)
end

RegisterNetEvent('lsrp_framework:client:notify', function(message, level)
	notify(message, level)
end)

exports('notify', function(message, level)
	notify(message, level)
end)