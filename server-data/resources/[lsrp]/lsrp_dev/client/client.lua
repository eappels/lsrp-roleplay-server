-- LSRP Dev Tools - Client Script
--
-- Developer/admin utility commands for in-game testing.
--
-- Commands:
--   /pos               - print current world coordinates and heading to F8 console
--   /heal              - restore the local ped to full health
--   /revive            - respawn the ped at its current location when dead
--   /wep [name]        - give a weapon (pistol/ak/rifle/knife/smg/shotgun/revolver)
--   /veh [model]       - spawn a vehicle 4 m in front of the player (default: comet7)
--   /ids               - toggle nearby player IDs (admin ACE check on server)
--
-- Note: noclip is defined in noclip.lua (F1 key by default).
-- Note: F3 toggles /ids via key mapping.

-- scroot location: Position: x=-647.54, y=-1720.88, z=24.5

local idOverlayEnabled = false
local idOverlayMaxDistance = 35.0

local function drawFloatingText(x, y, z, text)
    local onScreen, screenX, screenY = World3dToScreen2d(x, y, z)
    if not onScreen then
        return
    end

    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 215)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(screenX, screenY)
end

RegisterNetEvent('lsrp_dev:client:setIdOverlayEnabled', function(enabled)
    idOverlayEnabled = enabled == true
end)

local function requestIdOverlayToggle()
    TriggerServerEvent('lsrp_dev:server:toggleIdOverlay')
end

RegisterCommand('+lsrp_ids_toggle', function()
    requestIdOverlayToggle()
end, false)

RegisterCommand('-lsrp_ids_toggle', function()
end, false)

RegisterKeyMapping('+lsrp_ids_toggle', 'Toggle admin player ID overlay', 'keyboard', 'F3')

Citizen.CreateThread(function()
    while true do
        if idOverlayEnabled then
            local localPlayer = PlayerId()
            local localPed = PlayerPedId()
            local localCoords = GetEntityCoords(localPed)

            for _, player in ipairs(GetActivePlayers()) do
                if player ~= localPlayer then
                    local ped = GetPlayerPed(player)

                    if DoesEntityExist(ped) then
                        local pedCoords = GetEntityCoords(ped)
                        local distance = #(pedCoords - localCoords)

                        if distance <= idOverlayMaxDistance and HasEntityClearLosToEntity(localPed, ped, 17) then
                            local serverId = GetPlayerServerId(player)
                            local playerName = GetPlayerName(player) or 'Unknown'
                            drawFloatingText(pedCoords.x, pedCoords.y, pedCoords.z + 1.10, ('[%d] %s'):format(serverId, playerName))
                        end
                    end
                end
            end

            Citizen.Wait(0)
        else
            Citizen.Wait(500)
        end
    end
end)

Citizen.CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/ids', 'Toggle admin player ID overlay')
end)


RegisterCommand('pos', function(source, args)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    print(('Position: x=%.2f, y=%.2f, z=%.2f, heading=%.2f'):format(pos.x, pos.y, pos.z, heading))
end, false)

RegisterCommand('heal', function(source, args)
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
end, false)

RegisterCommand('revive', function(source, args)
	local ped = PlayerPedId()
	if IsEntityDead(ped) then
		local pos = GetEntityCoords(ped)
		local heading = GetEntityHeading(ped)
		local spawnTable = {
			x = pos.x,
			y = pos.y,
			z = pos.z,
			heading = heading,
			skipFade = true
		}
        local ok = pcall(function()
            exports['lsrp_spawner']:spawnPlayerDirect(spawnTable)
        end)
        if not ok then
            TriggerEvent('lsrp_spawner:spawnPlayer', GetEntityModel(ped), pos.x, pos.y, pos.z)
        end
	end
end, false)

RegisterCommand('wep', function(source, args, raw)
    local weaponArg = args[1]
    if not weaponArg or weaponArg == '' then
        print('Usage: /wep [weapon_name]  e.g. pistol, ak, rifle, knife')
        return
    end
    local name = string.lower(weaponArg)
    local map = {
        pistol = 'weapon_pistol',
        ak = 'weapon_assaultrifle',
        rifle = 'weapon_carbinerifle',
        knife = 'weapon_knife',
        smg = 'weapon_smg',
        shotgun = 'weapon_pumpshotgun',
        revolver = 'weapon_revolver'
    }
    local weaponName = name:match('^weapon_') and name or (map[name] or 'weapon_pistol')
    local hash = GetHashKey(weaponName)
    local ped = PlayerPedId()
    GiveWeaponToPed(ped, hash, 250, false, true)
    SetPedAmmo(ped, hash, 250)
    print(('Gave weapon %s'):format(weaponName))
end, false)

RegisterCommand('veh', function(source, args, raw)
    local modelArg = args[1]
    if not modelArg or modelArg == '' then
        modelArg = 'comet7'
    end
    local modelHash = tonumber(modelArg) or GetHashKey(modelArg)
    RequestModel(modelHash)
    local tries = 0
    while not HasModelLoaded(modelHash) and tries < 100 do
        RequestModel(modelHash)
        Citizen.Wait(0)
        tries = tries + 1
    end
    if not HasModelLoaded(modelHash) then
        print(('Failed to load model %s'):format(tostring(modelArg)))
        return
    end
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local distance = 4.0
    local coords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 4.0, 0.0)
    local veh = CreateVehicle(modelHash, coords.x, coords.y, coords.z, heading + 90, true, false)
    PlaceObjectOnGroundProperly(veh)
    if DoesEntityExist(veh) then
        SetVehicleNumberPlateText(veh, 'LSRP')
        SetModelAsNoLongerNeeded(modelHash)
        SetVehicleModKit(veh, 0)
        SetVehicleMod(veh, 11, 3, false)
        SetVehicleMod(veh, 12, 2, false)
        SetVehicleMod(veh, 13, 2, false)
        SetVehicleMod(veh, 15, 2, false)
        SetVehicleMod(veh, 18, 0, false)
        SetVehicleMod(veh, 46, 1, false)
        SetVehicleMod(veh, 40, 2, false)
		local index = math.random(0, 16)
        SetVehicleColours(veh, 84, 120)
        SetVehRadioStation(veh, "OFF")
    end
end, false)