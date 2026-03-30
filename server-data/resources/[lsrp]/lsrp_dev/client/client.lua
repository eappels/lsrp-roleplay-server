-- LSRP Dev Tools - Client Script
--
-- Developer/admin utility commands for in-game testing.
--
-- Commands:
--   /pos               - print current world coordinates and heading to F8 console
--   /tp [x] [y] [z]    - teleport to world coordinates
--   /heal              - restore the local ped to full health
--   /revive            - respawn the ped at its current location when dead
--   /wep [name]        - give a weapon (pistol/ak/rifle/knife/smg/shotgun/revolver)
--   /veh [model]       - spawn a vehicle 4 m in front of the player (default: comet7)
--   /setplate [text]   - set the plate of the vehicle you are currently in
--   /ids               - toggle nearby player IDs locally for everyone
--
-- Note: noclip is defined in noclip.lua (F1 key by default).
-- Note: Hold F3 to show nearby player IDs while pressed.

-- scroot location: Position: x=-647.54, y=-1720.88, z=24.5

local idOverlayEnabled = false
local idOverlayMaxDistance = 35.0
local OWNED_VEHICLE_ID_STATE_KEY = 'lsrpOwnedVehicleId'
local OWNED_VEHICLE_OWNER_STATE_KEY = 'lsrpVehicleOwner'
local OWNED_VEHICLE_OWNER_STATE_ID_KEY = 'lsrpVehicleOwnerStateId'

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

local function normalizePlateText(value)
    local trimmed = trimString(value)
    if not trimmed then
        return nil
    end

    local sanitized = trimmed:gsub('%s+', ''):upper():gsub('[^A-Z0-9]', '')
    if sanitized == '' then
        return nil
    end

    if #sanitized > 8 then
        sanitized = sanitized:sub(1, 8)
    end

    return sanitized
end

local function decodeVehicleProps(rawProps)
    if type(rawProps) == 'table' then
        return rawProps
    end

    local propsText = trimString(rawProps)
    if not propsText then
        return nil
    end

    local ok, decoded = pcall(function()
        return json.decode(propsText)
    end)

    if ok and type(decoded) == 'table' then
        return decoded
    end

    return nil
end

local function setOwnedVehicleState(vehicle, ownedVehicleId, ownerLicense, ownerStateId)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return
    end

    local entityState = Entity(vehicle).state
    if not entityState then
        return
    end

    local normalizedOwnedVehicleId = tonumber(ownedVehicleId)
    if normalizedOwnedVehicleId and normalizedOwnedVehicleId > 0 then
        entityState:set(OWNED_VEHICLE_ID_STATE_KEY, normalizedOwnedVehicleId, true)
    end

    if type(ownerLicense) == 'string' and ownerLicense ~= '' then
        entityState:set(OWNED_VEHICLE_OWNER_STATE_KEY, ownerLicense, true)
    end

    local normalizedOwnerStateId = tonumber(ownerStateId)
    if normalizedOwnerStateId and normalizedOwnerStateId > 0 then
        entityState:set(OWNED_VEHICLE_OWNER_STATE_ID_KEY, math.floor(normalizedOwnerStateId), true)
    end
end

local function setVehicleProperties(vehicle, props)
    if not DoesEntityExist(vehicle) or type(props) ~= 'table' then
        return
    end

    SetVehicleModKit(vehicle, 0)

    if props.color1 and props.color2 then
        SetVehicleColours(vehicle, props.color1, props.color2)
    end

    if props.pearlescentColor and props.wheelColor then
        SetVehicleExtraColours(vehicle, props.pearlescentColor, props.wheelColor)
    end

    if props.customPrimaryColor then
        SetVehicleCustomPrimaryColour(vehicle, props.customPrimaryColor[1], props.customPrimaryColor[2], props.customPrimaryColor[3])
    end

    if props.customSecondaryColor then
        SetVehicleCustomSecondaryColour(vehicle, props.customSecondaryColor[1], props.customSecondaryColor[2], props.customSecondaryColor[3])
    end

    if props.plate then
        SetVehicleNumberPlateText(vehicle, props.plate)
    end

    if props.plateIndex then
        SetVehicleNumberPlateTextIndex(vehicle, props.plateIndex)
    end

    if props.modSpoilers then SetVehicleMod(vehicle, 0, props.modSpoilers, false) end
    if props.modFrontBumper then SetVehicleMod(vehicle, 1, props.modFrontBumper, false) end
    if props.modRearBumper then SetVehicleMod(vehicle, 2, props.modRearBumper, false) end
    if props.modSideSkirt then SetVehicleMod(vehicle, 3, props.modSideSkirt, false) end
    if props.modExhaust then SetVehicleMod(vehicle, 4, props.modExhaust, false) end
    if props.modFrame then SetVehicleMod(vehicle, 5, props.modFrame, false) end
    if props.modGrille then SetVehicleMod(vehicle, 6, props.modGrille, false) end
    if props.modHood then SetVehicleMod(vehicle, 7, props.modHood, false) end
    if props.modFender then SetVehicleMod(vehicle, 8, props.modFender, false) end
    if props.modRightFender then SetVehicleMod(vehicle, 9, props.modRightFender, false) end
    if props.modRoof then SetVehicleMod(vehicle, 10, props.modRoof, false) end
    if props.modEngine then SetVehicleMod(vehicle, 11, props.modEngine, false) end
    if props.modBrakes then SetVehicleMod(vehicle, 12, props.modBrakes, false) end
    if props.modTransmission then SetVehicleMod(vehicle, 13, props.modTransmission, false) end
    if props.modHorns then SetVehicleMod(vehicle, 14, props.modHorns, false) end
    if props.modSuspension then SetVehicleMod(vehicle, 15, props.modSuspension, false) end
    if props.modArmor then SetVehicleMod(vehicle, 16, props.modArmor, false) end

    if props.modTurbo then ToggleVehicleMod(vehicle, 18, true) end
    if props.modXenon then ToggleVehicleMod(vehicle, 22, true) end

    if props.wheelType then
        SetVehicleWheelType(vehicle, props.wheelType)
    end

    if props.modFrontWheels then
        SetVehicleMod(vehicle, 23, props.modFrontWheels, props.modCustomTiresF or false)
    end

    if props.modBackWheels then
        SetVehicleMod(vehicle, 24, props.modBackWheels, props.modCustomTiresR or false)
    end

    if props.modPlateHolder then SetVehicleMod(vehicle, 25, props.modPlateHolder, false) end
    if props.modVanityPlate then SetVehicleMod(vehicle, 26, props.modVanityPlate, false) end
    if props.modTrimA then SetVehicleMod(vehicle, 27, props.modTrimA, false) end
    if props.modOrnaments then SetVehicleMod(vehicle, 28, props.modOrnaments, false) end
    if props.modDashboard then SetVehicleMod(vehicle, 29, props.modDashboard, false) end
    if props.modDial then SetVehicleMod(vehicle, 30, props.modDial, false) end
    if props.modDoorSpeaker then SetVehicleMod(vehicle, 31, props.modDoorSpeaker, false) end
    if props.modSeats then SetVehicleMod(vehicle, 32, props.modSeats, false) end
    if props.modSteeringWheel then SetVehicleMod(vehicle, 33, props.modSteeringWheel, false) end
    if props.modShifterLeavers then SetVehicleMod(vehicle, 34, props.modShifterLeavers, false) end
    if props.modAPlate then SetVehicleMod(vehicle, 35, props.modAPlate, false) end
    if props.modSpeakers then SetVehicleMod(vehicle, 36, props.modSpeakers, false) end
    if props.modTrunk then SetVehicleMod(vehicle, 37, props.modTrunk, false) end
    if props.modHydrolic then SetVehicleMod(vehicle, 38, props.modHydrolic, false) end
    if props.modEngineBlock then SetVehicleMod(vehicle, 39, props.modEngineBlock, false) end
    if props.modAirFilter then SetVehicleMod(vehicle, 40, props.modAirFilter, false) end
    if props.modStruts then SetVehicleMod(vehicle, 41, props.modStruts, false) end
    if props.modArchCover then SetVehicleMod(vehicle, 42, props.modArchCover, false) end
    if props.modAerials then SetVehicleMod(vehicle, 43, props.modAerials, false) end
    if props.modTrimB then SetVehicleMod(vehicle, 44, props.modTrimB, false) end
    if props.modTank then SetVehicleMod(vehicle, 45, props.modTank, false) end
    if props.modWindows then SetVehicleMod(vehicle, 46, props.modWindows, false) end
    if props.modLivery then SetVehicleMod(vehicle, 48, props.modLivery, false) end

    if props.windowTint then
        SetVehicleWindowTint(vehicle, props.windowTint)
    end

    if props.neonEnabled then
        SetVehicleNeonLightEnabled(vehicle, 0, props.neonEnabled[1])
        SetVehicleNeonLightEnabled(vehicle, 1, props.neonEnabled[2])
        SetVehicleNeonLightEnabled(vehicle, 2, props.neonEnabled[3])
        SetVehicleNeonLightEnabled(vehicle, 3, props.neonEnabled[4])
    end

    if props.neonColor then
        SetVehicleNeonLightsColour(vehicle, props.neonColor[1], props.neonColor[2], props.neonColor[3])
    end

    if props.tyreSmokeColor then
        SetVehicleTyreSmokeColor(vehicle, props.tyreSmokeColor[1], props.tyreSmokeColor[2], props.tyreSmokeColor[3])
    end

    if props.extras then
        for id, enabled in pairs(props.extras) do
            local extraId = tonumber(id)
            if extraId and DoesExtraExist(vehicle, extraId) then
                SetVehicleExtra(vehicle, extraId, not enabled)
            end
        end
    end

    if props.bodyHealth then
        SetVehicleBodyHealth(vehicle, props.bodyHealth + 0.0)
    end

    if props.engineHealth then
        SetVehicleEngineHealth(vehicle, props.engineHealth + 0.0)
    end

    if props.tankHealth then
        SetVehiclePetrolTankHealth(vehicle, props.tankHealth + 0.0)
    end

    if props.fuelLevel then
        SetVehicleFuelLevel(vehicle, props.fuelLevel + 0.0)
    end

    if props.dirtLevel then
        SetVehicleDirtLevel(vehicle, props.dirtLevel + 0.0)
    end

    if props.oilLevel then
        SetVehicleOilLevel(vehicle, props.oilLevel + 0.0)
    end
end

local function disableVehicleRadio(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return
    end

    if type(SetVehRadioStation) == 'function' then
        SetVehRadioStation(vehicle, 'OFF')
    end

    if type(SetVehicleRadioEnabled) == 'function' then
        SetVehicleRadioEnabled(vehicle, false)
    end
end

local function resolveOwnedVehicleModelHash(vehicleData, props)
    local candidates = {}
    local seen = {}

    local function addCandidate(value)
        local hash = tonumber(value)
        if not hash and type(value) == 'string' and value ~= '' then
            hash = GetHashKey(value)
        end

        if hash and hash ~= 0 and not seen[hash] then
            seen[hash] = true
            candidates[#candidates + 1] = hash
        end
    end

    addCandidate(vehicleData and vehicleData.model)
    addCandidate(vehicleData and vehicleData.vehicleModel)
    if type(props) == 'table' then
        addCandidate(props.model)
    end

    for _, modelHash in ipairs(candidates) do
        if IsModelInCdimage(modelHash) and IsModelAVehicle(modelHash) then
            return modelHash
        end
    end

    return nil
end

RegisterNetEvent('lsrp_dev:client:spawnOwnedVehicle', function(vehicleData)
    vehicleData = type(vehicleData) == 'table' and vehicleData or {}
    local props = decodeVehicleProps(vehicleData.props)
    local modelHash = resolveOwnedVehicleModelHash(vehicleData, props)
    if not modelHash then
        print('[lsrp_dev] Could not resolve a valid model for /devveh')
        return
    end

    RequestModel(modelHash)
    local timeoutAt = GetGameTimer() + 7000
    while not HasModelLoaded(modelHash) and GetGameTimer() < timeoutAt do
        Wait(10)
    end

    if not HasModelLoaded(modelHash) then
        print(('[lsrp_dev] Failed to load model for /devveh: %s'):format(tostring(vehicleData.model or vehicleData.vehicleModel or modelHash)))
        return
    end

    local ped = PlayerPedId()
    local heading = GetEntityHeading(ped)
    local spawnCoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 4.5, 0.0)
    local vehicle = CreateVehicle(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, heading, true, false)
    SetModelAsNoLongerNeeded(modelHash)

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        print('[lsrp_dev] Failed to create /devveh vehicle')
        return
    end

    SetVehicleOnGroundProperly(vehicle)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    setOwnedVehicleState(vehicle, vehicleData.ownedVehicleId, vehicleData.ownerLicense, vehicleData.ownerStateId)
    disableVehicleRadio(vehicle)

    if type(vehicleData.plate) == 'string' and vehicleData.plate ~= '' then
        SetVehicleNumberPlateText(vehicle, vehicleData.plate)
    end

    if props then
        setVehicleProperties(vehicle, props)
    end

    disableVehicleRadio(vehicle)
    TaskWarpPedIntoVehicle(ped, vehicle, -1)
    TriggerEvent('chat:addMessage', {
        color = { 255, 200, 0 },
        args = { 'LSRP Dev', ('Spawned your last used owned vehicle: %s'):format(tostring(vehicleData.plate or vehicleData.model or 'unknown')) }
    })
end)

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

RegisterNetEvent('lsrp_dev:client:printIdentityAudit', function(lines)
    if type(lines) ~= 'table' or #lines == 0 then
        print('[lsrp_dev] Identity audit: no lines received')
        return
    end

    print('===== LSRP Identity Audit =====')
    for _, line in ipairs(lines) do
        print(tostring(line))
    end
    print('===== End Identity Audit =====')
end)

local function setIdOverlayEnabled(enabled)
    idOverlayEnabled = enabled == true
end

RegisterCommand('+lsrp_ids_toggle', function()
    setIdOverlayEnabled(true)
end, false)

RegisterCommand('-lsrp_ids_toggle', function()
    setIdOverlayEnabled(false)
end, false)

RegisterKeyMapping('+lsrp_ids_toggle', 'Show nearby player IDs while held', 'keyboard', 'F3')

RegisterCommand('ids', function()
    setIdOverlayEnabled(not idOverlayEnabled)
    TriggerEvent('chat:addMessage', {
        color = { 255, 200, 0 },
        args = { 'LSRP Dev', idOverlayEnabled and 'Player ID overlay enabled.' or 'Player ID overlay disabled.' }
    })
end, false)

Citizen.CreateThread(function()
    while true do
        if idOverlayEnabled then
            local localPlayer = PlayerId()
            local localPed = PlayerPedId()
            local localCoords = GetEntityCoords(localPed)

            for _, player in ipairs(GetActivePlayers()) do
                local ped = GetPlayerPed(player)

                if DoesEntityExist(ped) then
                    local pedCoords = GetEntityCoords(ped)
                    local distance = #(pedCoords - localCoords)
                    local hasLineOfSight = player == localPlayer or HasEntityClearLosToEntity(localPed, ped, 17)

                    if distance <= idOverlayMaxDistance and hasLineOfSight then
                        local serverId = GetPlayerServerId(player)
                        local playerName = GetPlayerName(player) or 'Unknown'
                        drawFloatingText(pedCoords.x, pedCoords.y, pedCoords.z + 1.10, ('[%d] %s'):format(serverId, playerName))
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
    TriggerEvent('chat:addSuggestion', '/ids', 'Toggle nearby player ID overlay locally')
end)


local function runHealAction()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
end

local function runTeleportAction(payload)
    local x = tonumber(payload and payload.x)
    local y = tonumber(payload and payload.y)
    local z = tonumber(payload and payload.z)

    if not x or not y or not z then
        TriggerEvent('chat:addMessage', {
            color = { 255, 200, 0 },
            args = { 'LSRP Dev', 'Usage: /tp x y z' }
        })
        return
    end

    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) then
        TriggerEvent('chat:addMessage', {
            color = { 255, 200, 0 },
            args = { 'LSRP Dev', 'Could not find your player ped.' }
        })
        return
    end

    RequestCollisionAtCoord(x, y, z)

    if IsPedInAnyVehicle(ped, false) then
        SetPedCoordsKeepVehicle(ped, x + 0.0, y + 0.0, z + 0.0)
    else
        SetEntityCoords(ped, x + 0.0, y + 0.0, z + 0.0, false, false, false, false)
    end

    TriggerEvent('chat:addMessage', {
        color = { 255, 200, 0 },
        args = { 'LSRP Dev', ('Teleported to %.2f, %.2f, %.2f.'):format(x, y, z) }
    })
end

local function runReviveAction()
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
end

local function runWeaponAction(payload)
    local weaponArg = payload and payload.weaponArg
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
end

local function runVehicleAction(payload)
    local modelArg = payload and payload.modelArg
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
    local heading = GetEntityHeading(ped)
    local coords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 4.0, 0.0)
    local veh = CreateVehicle(modelHash, coords.x, coords.y, coords.z, heading + 90, true, false)
    PlaceObjectOnGroundProperly(veh)
    if DoesEntityExist(veh) then
        SetVehicleNumberPlateText(veh, 'LSRP01')
        SetModelAsNoLongerNeeded(modelHash)
        SetVehicleModKit(veh, 0)
        SetVehicleMod(veh, 11, 3, false)
        SetVehicleMod(veh, 12, 2, false)
        SetVehicleMod(veh, 13, 2, false)
        SetVehicleMod(veh, 15, 2, false)
        SetVehicleMod(veh, 18, 0, false)
        SetVehicleMod(veh, 46, 1, false)
        SetVehicleMod(veh, 40, 2, false)
		SetVehicleColours(veh, 84, 120)
        SetVehRadioStation(veh, 'OFF')
    end
end

local function runSetPlateAction(payload)
    local plate = normalizePlateText(payload and payload.plateText)
    if not plate then
        TriggerEvent('chat:addMessage', {
            color = { 255, 200, 0 },
            args = { 'LSRP Dev', 'Usage: /setplate xxxxxx' }
        })
        return
    end

    local ped = PlayerPedId()
    if ped == 0 or not IsPedInAnyVehicle(ped, false) then
        TriggerEvent('chat:addMessage', {
            color = { 255, 200, 0 },
            args = { 'LSRP Dev', 'You must be inside a vehicle.' }
        })
        return
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        TriggerEvent('chat:addMessage', {
            color = { 255, 200, 0 },
            args = { 'LSRP Dev', 'Could not find the current vehicle.' }
        })
        return
    end

    SetVehicleNumberPlateText(vehicle, plate)

    TriggerEvent('chat:addMessage', {
        color = { 255, 200, 0 },
        args = { 'LSRP Dev', ('Vehicle plate set to %s.'):format(plate) }
    })
end

RegisterNetEvent('lsrp_dev:client:runPrivilegedAction', function(actionName, payload)
    if actionName == 'tp' then
        runTeleportAction(type(payload) == 'table' and payload or {})
        return
    end

    if actionName == 'heal' then
        runHealAction()
        return
    end

    if actionName == 'revive' then
        runReviveAction()
        return
    end

    if actionName == 'wep' then
        runWeaponAction(type(payload) == 'table' and payload or {})
        return
    end

    if actionName == 'veh' then
        runVehicleAction(type(payload) == 'table' and payload or {})
        return
    end

    if actionName == 'setplate' then
        runSetPlateAction(type(payload) == 'table' and payload or {})
    end
end)


RegisterCommand('pos', function(source, args)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    print(('Position: x=%.2f, y=%.2f, z=%.2f, heading=%.2f'):format(pos.x, pos.y, pos.z, heading))
end, false)

RegisterCommand('tp', function(source, args)
    TriggerServerEvent('lsrp_dev:server:requestPrivilegedAction', 'tp', {
        x = args and args[1] or nil,
        y = args and args[2] or nil,
        z = args and args[3] or nil
    })
end, false)

RegisterCommand('heal', function(source, args)
    TriggerServerEvent('lsrp_dev:server:requestPrivilegedAction', 'heal', {})
end, false)

RegisterCommand('revive', function(source, args)
    TriggerServerEvent('lsrp_dev:server:requestPrivilegedAction', 'revive', {})
end, false)

RegisterCommand('wep', function(source, args, raw)
    TriggerServerEvent('lsrp_dev:server:requestPrivilegedAction', 'wep', {
        weaponArg = args[1]
    })
end, false)

RegisterCommand('veh', function(source, args, raw)
    TriggerServerEvent('lsrp_dev:server:requestPrivilegedAction', 'veh', {
        modelArg = args[1]
    })
end, false)

RegisterCommand('setplate', function(source, args, raw)
    local plateText = nil

    if type(raw) == 'string' then
        plateText = raw:match('^setplate%s+(.+)$')
    end

    if not plateText then
        plateText = args and args[1] or nil
    end

    TriggerServerEvent('lsrp_dev:server:requestPrivilegedAction', 'setplate', {
        plateText = plateText
    })
end, false)