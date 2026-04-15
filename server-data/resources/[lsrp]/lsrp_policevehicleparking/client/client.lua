local RESOURCE_NAME = GetCurrentResourceName()
local inZone = false
local currentZone = nil
local parkingBlips = {}
local parkingZones = {}
local parkedVehicles = {}
local uiOpen = false
local OWNED_VEHICLE_ID_STATE_KEY = 'lsrpEmergencyOwnedVehicleId'
local OWNED_VEHICLE_OWNER_STATE_KEY = 'lsrpEmergencyVehicleOwner'
local OWNED_VEHICLE_OWNER_STATE_ID_KEY = 'lsrpEmergencyVehicleOwnerStateId'
local LOCK_STATE_BAG_KEY = 'lsrpEmergencyVehicleLocked'
local VEHICLE_STORAGE_COMMAND_NAME = tostring((Config and Config.VehicleStorage and Config.VehicleStorage.commandName) or 'vehstorage')
local VEHICLE_STORAGE_KEYMAP_COMMAND = '+' .. RESOURCE_NAME .. ':openVehicleStorage'
local VEHICLE_STORAGE_KEYMAP_RELEASE_COMMAND = '-' .. RESOURCE_NAME .. ':openVehicleStorage'

local function canStoreVehiclesInZone(zoneCfg)
    return type(zoneCfg) == 'table' and zoneCfg.allowStore ~= false
end

local function getParkingZoneByName(zoneName)
    if type(zoneName) ~= 'string' or zoneName == '' then
        return nil
    end

    local normalizedName = string.lower(zoneName)

    for _, zoneCfg in ipairs(Config.ParkingZones) do
        if type(zoneCfg.name) == 'string' and string.lower(zoneCfg.name) == normalizedName then
            return zoneCfg
        end
    end

    return nil
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

local function getVehicleStorageConfig()
    return (Config and Config.VehicleStorage) or {}
end

local function isVehicleStorageEnabled()
    return getVehicleStorageConfig().enabled ~= false
end

local function getVehicleStorageOpenDistance()
    return math.max(1.5, tonumber(getVehicleStorageConfig().openDistance) or 2.5)
end

local function getVehicleStorageRearOffsetPadding()
    return math.max(0.0, tonumber(getVehicleStorageConfig().rearOffsetPadding) or 0.75)
end

local function getVehicleStorageKeyLabel()
    return trimString(getVehicleStorageConfig().keyLabel) or trimString(getVehicleStorageConfig().defaultKey) or 'G'
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

local function prettifyVehicleLabel(label)
    local text = trimString(label)
    if not text then
        return nil
    end

    text = text:gsub('[_%-]+', ' '):gsub('%s+', ' ')

    if text == '' then
        return nil
    end

    if text == string.upper(text) then
        text = string.lower(text)
    end

    text = text:gsub('(%a)([%w]*)', function(first, rest)
        return string.upper(first) .. string.lower(rest)
    end)

    return text
end

local function resolveVehicleDisplayName(vehicleData)
    if type(vehicleData) ~= 'table' then
        return 'Unknown'
    end

    local props = decodeVehicleProps(vehicleData.vehicle_props)
    local rawModel = trimString(vehicleData.vehicle_display_name)
        or trimString(vehicleData.vehicle_model)
        or trimString(props and props.modelName)
    local modelHash = tonumber(rawModel)

    if not modelHash and props and props.model ~= nil then
        modelHash = tonumber(props.model)
    end

    if not modelHash and rawModel then
        modelHash = GetHashKey(rawModel)
    end

    if modelHash and modelHash ~= 0 and IsModelInCdimage(modelHash) and IsModelAVehicle(modelHash) then
        local displayCode = trimString(GetDisplayNameFromVehicleModel(modelHash))
        if displayCode and displayCode ~= 'CARNOTFOUND' then
            local labelText = trimString(GetLabelText(displayCode))
            if labelText and labelText ~= 'NULL' then
                return labelText
            end

            local prettyCode = prettifyVehicleLabel(displayCode)
            if prettyCode then
                return prettyCode
            end
        end
    end

    local prettyRawModel = prettifyVehicleLabel(rawModel)
    if prettyRawModel then
        return prettyRawModel
    end

    local prettyPropsModel = prettifyVehicleLabel(props and props.modelName)
    if prettyPropsModel then
        return prettyPropsModel
    end

    return rawModel or 'Unknown'
end

local function normalizeVehiclesForUi(vehicles)
    if type(vehicles) ~= 'table' then
        return {}
    end

    local normalizedVehicles = {}

    for index, vehicle in ipairs(vehicles) do
        if type(vehicle) == 'table' then
            local normalizedVehicle = {}

            for key, value in pairs(vehicle) do
                normalizedVehicle[key] = value
            end

            normalizedVehicle.vehicle_display_name = resolveVehicleDisplayName(vehicle)
            normalizedVehicles[index] = normalizedVehicle
        end
    end

    return normalizedVehicles
end

-- Helper function to get vehicle properties (all customization)
local function getVehicleProperties(vehicle)
    if not DoesEntityExist(vehicle) then
        return nil
    end

    local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
    local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)
    local extras = {}
    
    for extraId = 0, 12 do
        if DoesExtraExist(vehicle, extraId) then
            extras[tostring(extraId)] = IsVehicleExtraTurnedOn(vehicle, extraId)
        end
    end

    local doorsBroken, windowsBroken = {}, {}
    local tyreBurst = {}
    
    for i = 0, 5 do
        doorsBroken[i] = IsVehicleDoorDamaged(vehicle, i)
        windowsBroken[i] = not IsVehicleWindowIntact(vehicle, i)
    end
    
    for i = 0, 7 do
        tyreBurst[i] = IsVehicleTyreBurst(vehicle, i, false)
    end

    return {
        model = GetEntityModel(vehicle),
        
        -- Colors
        pearlescentColor = pearlescentColor,
        wheelColor = wheelColor,
        color1 = colorPrimary,
        color2 = colorSecondary,
        
        -- Custom colors
        customPrimaryColor = {GetVehicleCustomPrimaryColour(vehicle)},
        customSecondaryColor = {GetVehicleCustomSecondaryColour(vehicle)},
        
        -- Paint types
        paintType1 = GetVehicleModColor_1(vehicle),
        paintType2 = GetVehicleModColor_2(vehicle),
        
        -- Plates
        plate = GetVehicleNumberPlateText(vehicle),
        plateIndex = GetVehicleNumberPlateTextIndex(vehicle),
        
        -- Damage
        bodyHealth = GetVehicleBodyHealth(vehicle),
        engineHealth = GetVehicleEngineHealth(vehicle),
        tankHealth = GetVehiclePetrolTankHealth(vehicle),
        fuelLevel = GetVehicleFuelLevel(vehicle),
        dirtLevel = GetVehicleDirtLevel(vehicle),
        oilLevel = GetVehicleOilLevel(vehicle),
        
        -- Doors and windows
        doorsBroken = doorsBroken,
        windowsBroken = windowsBroken,
        tyreBurst = tyreBurst,
        
        -- Mods
        modSpoilers = GetVehicleMod(vehicle, 0),
        modFrontBumper = GetVehicleMod(vehicle, 1),
        modRearBumper = GetVehicleMod(vehicle, 2),
        modSideSkirt = GetVehicleMod(vehicle, 3),
        modExhaust = GetVehicleMod(vehicle, 4),
        modFrame = GetVehicleMod(vehicle, 5),
        modGrille = GetVehicleMod(vehicle, 6),
        modHood = GetVehicleMod(vehicle, 7),
        modFender = GetVehicleMod(vehicle, 8),
        modRightFender = GetVehicleMod(vehicle, 9),
        modRoof = GetVehicleMod(vehicle, 10),
        
        modEngine = GetVehicleMod(vehicle, 11),
        modBrakes = GetVehicleMod(vehicle, 12),
        modTransmission = GetVehicleMod(vehicle, 13),
        modHorns = GetVehicleMod(vehicle, 14),
        modSuspension = GetVehicleMod(vehicle, 15),
        modArmor = GetVehicleMod(vehicle, 16),
        
        modTurbo = IsToggleModOn(vehicle, 18),
        modSmokeEnabled = IsToggleModOn(vehicle, 20),
        modXenon = IsToggleModOn(vehicle, 22),
        
        modFrontWheels = GetVehicleMod(vehicle, 23),
        modBackWheels = GetVehicleMod(vehicle, 24),
        
        modPlateHolder = GetVehicleMod(vehicle, 25),
        modVanityPlate = GetVehicleMod(vehicle, 26),
        modTrimA = GetVehicleMod(vehicle, 27),
        modOrnaments = GetVehicleMod(vehicle, 28),
        modDashboard = GetVehicleMod(vehicle, 29),
        modDial = GetVehicleMod(vehicle, 30),
        modDoorSpeaker = GetVehicleMod(vehicle, 31),
        modSeats = GetVehicleMod(vehicle, 32),
        modSteeringWheel = GetVehicleMod(vehicle, 33),
        modShifterLeavers = GetVehicleMod(vehicle, 34),
        modAPlate = GetVehicleMod(vehicle, 35),
        modSpeakers = GetVehicleMod(vehicle, 36),
        modTrunk = GetVehicleMod(vehicle, 37),
        modHydrolic = GetVehicleMod(vehicle, 38),
        modEngineBlock = GetVehicleMod(vehicle, 39),
        modAirFilter = GetVehicleMod(vehicle, 40),
        modStruts = GetVehicleMod(vehicle, 41),
        modArchCover = GetVehicleMod(vehicle, 42),
        modAerials = GetVehicleMod(vehicle, 43),
        modTrimB = GetVehicleMod(vehicle, 44),
        modTank = GetVehicleMod(vehicle, 45),
        modWindows = GetVehicleMod(vehicle, 46),
        modLivery = GetVehicleMod(vehicle, 48),
        
        -- Wheel type and custom tires
        wheelType = GetVehicleWheelType(vehicle),
        modCustomTiresF = GetVehicleModVariation(vehicle, 23),
        modCustomTiresR = GetVehicleModVariation(vehicle, 24),
        
        -- Neon
        neonEnabled = {
            IsVehicleNeonLightEnabled(vehicle, 0),
            IsVehicleNeonLightEnabled(vehicle, 1),
            IsVehicleNeonLightEnabled(vehicle, 2),
            IsVehicleNeonLightEnabled(vehicle, 3)
        },
        neonColor = {GetVehicleNeonLightsColour(vehicle)},
        
        -- Tire smoke color
        tyreSmokeColor = {GetVehicleTyreSmokeColor(vehicle)},
        
        -- Window tint
        windowTint = GetVehicleWindowTint(vehicle),
        
        -- Extras
        extras = extras
    }
end

-- Helper function to set vehicle properties
local function setVehicleProperties(vehicle, props)
    if not DoesEntityExist(vehicle) or not props then
        return
    end

    SetVehicleModKit(vehicle, 0)
    
    -- Colors
    if props.color1 and props.color2 then
        SetVehicleColours(vehicle, props.color1, props.color2)
    end
    
    if props.pearlescentColor and props.wheelColor then
        SetVehicleExtraColours(vehicle, props.pearlescentColor, props.wheelColor)
    end
    
    -- Custom colors
    if props.customPrimaryColor then
        SetVehicleCustomPrimaryColour(vehicle, props.customPrimaryColor[1], props.customPrimaryColor[2], props.customPrimaryColor[3])
    end
    
    if props.customSecondaryColor then
        SetVehicleCustomSecondaryColour(vehicle, props.customSecondaryColor[1], props.customSecondaryColor[2], props.customSecondaryColor[3])
    end
    
    -- Plates
    if props.plate then
        SetVehicleNumberPlateText(vehicle, props.plate)
    end
    
    if props.plateIndex then
        SetVehicleNumberPlateTextIndex(vehicle, props.plateIndex)
    end
    
    -- Mods
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
    
    -- Wheels
    if props.wheelType then
        SetVehicleWheelType(vehicle, props.wheelType)
    end
    
    if props.modFrontWheels then
        SetVehicleMod(vehicle, 23, props.modFrontWheels, props.modCustomTiresF or false)
    end
    
    if props.modBackWheels then
        SetVehicleMod(vehicle, 24, props.modBackWheels, props.modCustomTiresR or false)
    end
    
    -- Other mods
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
    
    -- Window tint
    if props.windowTint then
        SetVehicleWindowTint(vehicle, props.windowTint)
    end
    
    -- Neon
    if props.neonEnabled then
        SetVehicleNeonLightEnabled(vehicle, 0, props.neonEnabled[1])
        SetVehicleNeonLightEnabled(vehicle, 1, props.neonEnabled[2])
        SetVehicleNeonLightEnabled(vehicle, 2, props.neonEnabled[3])
        SetVehicleNeonLightEnabled(vehicle, 3, props.neonEnabled[4])
    end
    
    if props.neonColor then
        SetVehicleNeonLightsColour(vehicle, props.neonColor[1], props.neonColor[2], props.neonColor[3])
    end
    
    -- Tire smoke
    if props.tyreSmokeColor then
        SetVehicleTyreSmokeColor(vehicle, props.tyreSmokeColor[1], props.tyreSmokeColor[2], props.tyreSmokeColor[3])
    end
    
    -- Extras
    if props.extras then
        for id, enabled in pairs(props.extras) do
            local extraId = tonumber(id)
            if DoesExtraExist(vehicle, extraId) then
                SetVehicleExtra(vehicle, extraId, not enabled)
            end
        end
    end
    
    -- Damage
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

-- Create blips for parking zones
local function destroyParkingZones()
    for i = 1, #parkingZones do
        local zone = parkingZones[i]
        if zone and type(zone.destroy) == 'function' then
            zone:destroy()
        end
    end
    parkingZones = {}
end

local function createParkingZones()
    destroyParkingZones()
    
    if type(BoxZone) ~= 'table' or type(BoxZone.Create) ~= 'function' then
        print('[lsrp_policevehicleparking] BoxZone is not available. Ensure polyzone is started.')
        return
    end

    local zoneDebugEnabled = Config.showParkingZoneDebug
    
    for index, zoneCfg in ipairs(Config.ParkingZones) do
        local zone = BoxZone:Create(zoneCfg.coords, zoneCfg.size.x, zoneCfg.size.y, {
            name = zoneCfg.name,
            heading = zoneCfg.rotation,
            minZ = zoneCfg.coords.z - (zoneCfg.size.z / 2.0),
            maxZ = zoneCfg.coords.z + (zoneCfg.size.z / 2.0),
            debugPoly = zoneDebugEnabled == true
        })
        
        zone:onPlayerInOut(function(isInside)
            if isInside then
                inZone = true
                currentZone = zoneCfg
            else
                if currentZone and currentZone.name == zoneCfg.name then
                    inZone = false
                    currentZone = nil
                    closeParkingUI()
                end
            end
        end)
        
        parkingZones[#parkingZones + 1] = zone
        print(('[lsrp_policevehicleparking] Created zone: %s'):format(zoneCfg.name))
        
        -- Create blip
        if zoneCfg.blip then
            local blip = AddBlipForCoord(zoneCfg.coords.x, zoneCfg.coords.y, zoneCfg.coords.z)
            SetBlipSprite(blip, zoneCfg.blip.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, zoneCfg.blip.scale)
            SetBlipColour(blip, zoneCfg.blip.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(zoneCfg.blip.label)
            EndTextCommandSetBlipName(blip)
            table.insert(parkingBlips, blip)
        end
    end
end

-- Initialize zones when resource starts
CreateThread(function()
    Wait(1000) -- Wait for polyzone to be ready
    createParkingZones()
end)

-- Interaction prompt thread
CreateThread(function()
    while true do
        local sleep = 500
        
        if inZone and currentZone then
            sleep = 0
            
            -- Show help text
            BeginTextCommandDisplayHelp("STRING")
            AddTextComponentString("Press ~INPUT_CONTEXT~ to open parking menu")
            EndTextCommandDisplayHelp(0, false, true, -1)
            
            if IsControlJustReleased(0, Config.OpenKey) then
                openParkingUI()
            end
        end
        
        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        local sleep = 750

        if isVehicleStorageEnabled() then
            local target = getNearbyOwnedVehicleStorageTarget()
            if target then
                sleep = 0

                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentString(('Press %s to open vehicle storage'):format(getVehicleStorageKeyLabel()))
                EndTextCommandDisplayHelp(0, false, true, -1)
            end
        end

        Wait(sleep)
    end
end)

-- Open parking UI
function openParkingUI()
    if not currentZone or uiOpen then return end
    
    uiOpen = true
    SetNuiFocus(true, true)
    
    -- Request parked vehicles from server
    TriggerServerEvent('lsrp_policevehicleparking:server:getParkedVehicles', currentZone.name)
    
    SendNUIMessage({
        action = 'openUI',
        zoneName = currentZone.name,
        maxSlots = currentZone.maxSlots,
        canStoreVehicle = canStoreVehiclesInZone(currentZone)
    })
end

local function openParkingZoneByName(zoneName)
    local zoneCfg = getParkingZoneByName(zoneName)
    if not zoneCfg then
        TriggerEvent(RESOURCE_NAME .. ':client:notify', 'Emergency garage location not found', 'error')
        return false
    end

    currentZone = zoneCfg
    openParkingUI()
    return true
end

local function getOwnedVehicleId(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return nil
    end

    local entityState = Entity(vehicle).state
    if not entityState then
        return nil
    end

    local ownedVehicleId = tonumber(entityState[OWNED_VEHICLE_ID_STATE_KEY])
    if not ownedVehicleId or ownedVehicleId <= 0 then
        return nil
    end

    return ownedVehicleId
end

local function isVehicleStorageLocked(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return false
    end

    local entityState = Entity(vehicle).state
    if entityState and entityState[LOCK_STATE_BAG_KEY] ~= nil then
        return entityState[LOCK_STATE_BAG_KEY] == true
    end

    local lockStatus = GetVehicleDoorLockStatus(vehicle)
    return lockStatus == 2 or lockStatus == 4 or lockStatus == 7 or lockStatus == 10
end

local function getVehicleStorageAccessPoint(vehicle)
    local modelHash = GetEntityModel(vehicle)
    if modelHash == 0 then
        return GetEntityCoords(vehicle)
    end

    local minDim, _ = GetModelDimensions(modelHash)
    return GetOffsetFromEntityInWorldCoords(vehicle, 0.0, (minDim.y or 0.0) - getVehicleStorageRearOffsetPadding(), 0.0)
end

local function getNearbyOwnedVehicleStorageTarget()
    if not isVehicleStorageEnabled() then
        return nil, 'storage_disabled'
    end

    local playerPed = PlayerPedId()
    if playerPed == 0 or not DoesEntityExist(playerPed) then
        return nil, 'invalid_ped'
    end

    if IsPedInAnyVehicle(playerPed, false) then
        return nil, 'in_vehicle'
    end

    local playerCoords = GetEntityCoords(playerPed)
    local maxDistance = getVehicleStorageOpenDistance()
    local bestTarget = nil
    local lockedTargetNearby = false

    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if vehicle ~= 0 and DoesEntityExist(vehicle) then
            local ownedVehicleId = getOwnedVehicleId(vehicle)
            if ownedVehicleId then
                local accessPoint = getVehicleStorageAccessPoint(vehicle)
                local accessDistance = #(playerCoords - accessPoint)
                if accessDistance <= maxDistance then
                    if isVehicleStorageLocked(vehicle) then
                        lockedTargetNearby = true
                    elseif not bestTarget or accessDistance < bestTarget.distance then
                        bestTarget = {
                            vehicle = vehicle,
                            ownedVehicleId = ownedVehicleId,
                            plate = trimString(GetVehicleNumberPlateText(vehicle)),
                            distance = accessDistance
                        }
                    end
                end
            end
        end
    end

    if not bestTarget then
        if lockedTargetNearby then
            return nil, 'locked'
        end

        return nil, 'no_vehicle'
    end

    return bestTarget, nil
end

local function requestOpenVehicleStorage(showError)
    local target, errorCode = getNearbyOwnedVehicleStorageTarget()
    if not target then
        if showError ~= false then
            if errorCode == 'in_vehicle' then
                TriggerEvent('lsrp_policevehicleparking:client:notify', 'Exit the vehicle to access the trunk', 'error')
            elseif errorCode == 'locked' then
                TriggerEvent('lsrp_policevehicleparking:client:notify', 'Unlock the vehicle before accessing the trunk', 'error')
            else
                TriggerEvent('lsrp_policevehicleparking:client:notify', 'Move closer to the rear of an owned vehicle to access the trunk', 'error')
            end
        end
        return false
    end

    if uiOpen then
        closeParkingUI()
    end

    TriggerServerEvent('lsrp_policevehicleparking:server:openVehicleStorage', {
        ownedVehicleId = target.ownedVehicleId,
        plate = target.plate
    })
    return true
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

-- Close parking UI
function closeParkingUI()
    if not uiOpen then return end
    
    uiOpen = false
    SetNuiFocus(false, false)
    
    SendNUIMessage({
        action = 'closeUI'
    })
end

-- NUI Callbacks
RegisterNUICallback('close', function(data, cb)
    closeParkingUI()
    cb('ok')
end)

RegisterNUICallback('storeVehicle', function(data, cb)
    if not currentZone then
        closeParkingUI()
        TriggerEvent('lsrp_policevehicleparking:client:notify', 'You are no longer in a parking zone', 'error')
        cb('error')
        return
    end

    if not canStoreVehiclesInZone(currentZone) then
        TriggerEvent('lsrp_policevehicleparking:client:notify', 'This is a private delivery parking zone and cannot be used for manual parking', 'error')
        cb('error')
        return
    end
    
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    
    if vehicle == 0 then
        TriggerEvent('lsrp_policevehicleparking:client:notify', 'You must be in a vehicle to park it', 'error')
        cb('error')
        return
    end
    
    if GetPedInVehicleSeat(vehicle, -1) ~= playerPed then
        TriggerEvent('lsrp_policevehicleparking:client:notify', 'You must be in the driver seat', 'error')
        cb('error')
        return
    end
    
    local vehicleProps = getVehicleProperties(vehicle)
    local vehicleModel = GetEntityModel(vehicle)
    local vehiclePlate = GetVehicleNumberPlateText(vehicle)
    local ownedVehicleId = getOwnedVehicleId(vehicle)
    
    TriggerServerEvent('lsrp_policevehicleparking:server:storeVehicle', {
        model = vehicleModel,
        plate = vehiclePlate,
        props = vehicleProps,
        netId = VehToNet(vehicle),
        ownedVehicleId = ownedVehicleId
    }, currentZone.name)

    closeParkingUI()
    cb('ok')
end)

RegisterNUICallback('retrieveVehicle', function(data, cb)
    local parkingId = data and tonumber(data.id)
    local vehiclePlate = data and data.plate

    if not parkingId and (not vehiclePlate or vehiclePlate == '') then
        cb('error')
        return
    end

    TriggerServerEvent('lsrp_policevehicleparking:server:retrieveVehicle', {
        id = parkingId,
        plate = vehiclePlate
    })

    closeParkingUI()
    cb('ok')
end)

RegisterNUICallback('refreshVehicles', function(data, cb)
    if currentZone then
        TriggerServerEvent('lsrp_policevehicleparking:server:getParkedVehicles', currentZone.name)
    end
    cb('ok')
end)

-- Client events
RegisterNetEvent('lsrp_policevehicleparking:client:receiveParkedVehicles', function(vehicles)
    local normalizedVehicles = normalizeVehiclesForUi(vehicles)
    parkedVehicles = normalizedVehicles
    
    SendNUIMessage({
        action = 'updateVehicles',
        vehicles = normalizedVehicles
    })
end)

local function ejectAllVehicleOccupants(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return true
    end

    local maxPassengers = tonumber(GetVehicleMaxNumberOfPassengers(vehicle)) or 0
    local maxSeatIndex = math.max(maxPassengers - 1, -1)

    local function hasOccupants()
        for seat = -1, maxSeatIndex do
            if GetPedInVehicleSeat(vehicle, seat) ~= 0 then
                return true
            end
        end

        return false
    end

    for seat = -1, maxSeatIndex do
        local occupant = GetPedInVehicleSeat(vehicle, seat)
        if occupant ~= 0 then
            TaskLeaveVehicle(occupant, vehicle, 0)
        end
    end

    local waitUntil = GetGameTimer() + 4500
    while GetGameTimer() < waitUntil do
        if not hasOccupants() then
            return true
        end

        Wait(100)
    end

    for seat = -1, maxSeatIndex do
        local occupant = GetPedInVehicleSeat(vehicle, seat)
        if occupant ~= 0 and not IsPedAPlayer(occupant) then
            TaskLeaveVehicle(occupant, vehicle, 4160)
        end
    end

    waitUntil = GetGameTimer() + 1500
    while GetGameTimer() < waitUntil do
        if not hasOccupants() then
            return true
        end

        Wait(100)
    end

    return not hasOccupants()
end

local function requestEntityControl(entity, timeoutMs)
    if entity == 0 or not DoesEntityExist(entity) then
        return false
    end

    if not NetworkGetEntityIsNetworked(entity) then
        return true
    end

    local timeoutAt = GetGameTimer() + (timeoutMs or 2000)
    NetworkRequestControlOfEntity(entity)

    while GetGameTimer() < timeoutAt do
        if NetworkHasControlOfEntity(entity) then
            return true
        end

        Wait(0)
        NetworkRequestControlOfEntity(entity)
    end

    return NetworkHasControlOfEntity(entity)
end

local function tryDeleteStoredVehicle(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return true
    end

    requestEntityControl(vehicle, 2500)
    SetEntityAsMissionEntity(vehicle, true, true)
    DeleteVehicle(vehicle)

    if DoesEntityExist(vehicle) then
        DeleteEntity(vehicle)
    end

    return not DoesEntityExist(vehicle)
end

local function waitBeforeStoredVehicleDelete(vehicle, delayMs)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return false
    end

    Wait(math.max(0, math.floor(tonumber(delayMs) or 0)))
    return vehicle ~= 0 and DoesEntityExist(vehicle)
end

local function waitForVehicleToEmptyAndDelete(vehicle, timeoutMs)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return true
    end

    local maxPassengers = tonumber(GetVehicleMaxNumberOfPassengers(vehicle)) or 0
    local maxSeatIndex = math.max(maxPassengers - 1, -1)
    local timeoutAt = GetGameTimer() + (timeoutMs or 8000)

    while GetGameTimer() < timeoutAt do
        local hasOccupants = false

        for seat = -1, maxSeatIndex do
            if GetPedInVehicleSeat(vehicle, seat) ~= 0 then
                hasOccupants = true
                break
            end
        end

        if not hasOccupants then
            if not waitBeforeStoredVehicleDelete(vehicle, 3000) then
                return true
            end

            return tryDeleteStoredVehicle(vehicle)
        end

        Wait(250)
    end

    return false
end

RegisterNetEvent('lsrp_policevehicleparking:client:vehicleStored', function(success, storedVehicleNetId)
    if success then
        local playerPed = PlayerPedId()
        local vehicle = 0

        local netId = tonumber(storedVehicleNetId)
        if netId and netId > 0 and NetworkDoesNetworkIdExist(netId) then
            vehicle = NetToVeh(netId)
        end

        if vehicle == 0 then
            vehicle = GetVehiclePedIsIn(playerPed, true)
        end
        
        if vehicle ~= 0 and DoesEntityExist(vehicle) then
            local allOccupantsExited = ejectAllVehicleOccupants(vehicle)

            if not allOccupantsExited then
                TriggerEvent('lsrp_policevehicleparking:client:notify', 'Vehicle was stored, waiting for passengers to exit before despawning', 'info')

                CreateThread(function()
                    if not waitForVehicleToEmptyAndDelete(vehicle, 8000) then
                        TriggerEvent('lsrp_policevehicleparking:client:notify', 'Vehicle was stored but could not be despawned immediately', 'error')
                    end
                end)

                return
            end

            if not waitBeforeStoredVehicleDelete(vehicle, 3000) then
                return
            end

            if not tryDeleteStoredVehicle(vehicle) then
                TriggerEvent('lsrp_policevehicleparking:client:notify', 'Vehicle was stored but could not be despawned immediately', 'error')
            end
        end
        
        -- Refresh the vehicle list
        if currentZone then
            TriggerServerEvent('lsrp_policevehicleparking:server:getParkedVehicles', currentZone.name)
        end
    end
end)

RegisterNetEvent('lsrp_policevehicleparking:client:exitStoredVehicle', function(storedVehicleNetId)
    local netId = tonumber(storedVehicleNetId)
    if not netId or netId <= 0 or not NetworkDoesNetworkIdExist(netId) then
        return
    end

    local vehicle = NetToVeh(netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return
    end

    local playerPed = PlayerPedId()
    if playerPed == 0 or not DoesEntityExist(playerPed) or not IsPedInVehicle(playerPed, vehicle, false) then
        return
    end

    TaskLeaveVehicle(playerPed, vehicle, 0)
end)

local function sendRetrievalSpawnResult(requestId, success, reason)
    local normalizedRequestId = tonumber(requestId)
    if not normalizedRequestId then
        return
    end

    TriggerServerEvent('lsrp_policevehicleparking:server:retrievalSpawnResult', {
        requestId = normalizedRequestId,
        success = success == true,
        reason = tostring(reason or '')
    })
end

local function resolveRetrievalModelHash(vehicleData)
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

    if type(vehicleData) == 'table' then
        addCandidate(vehicleData.model)

        if type(vehicleData.props) == 'table' then
            addCandidate(vehicleData.props.model)
        end
    end

    for _, modelHash in ipairs(candidates) do
        if IsModelInCdimage(modelHash) and IsModelAVehicle(modelHash) then
            return modelHash
        end
    end

    return nil
end

RegisterNetEvent('lsrp_policevehicleparking:client:spawnVehicle', function(vehicleData)
    local retrievalRequestId = tonumber(vehicleData and vehicleData.retrievalRequestId)
    local requestedZone = getParkingZoneByName(vehicleData and vehicleData.parkingZone)
    local zoneCfg = requestedZone or currentZone

    if not zoneCfg then
        sendRetrievalSpawnResult(retrievalRequestId, false, 'missing_zone')
        TriggerEvent('lsrp_policevehicleparking:client:notify', 'Vehicle retrieval failed: parking zone is unavailable', 'error')
        return
    end

    local zoneName = zoneCfg.name
    local zoneCoords = zoneCfg.coords
    local zoneRotation = zoneCfg.rotation or 0.0

    local playerPed = PlayerPedId()
    local modelHash = resolveRetrievalModelHash(vehicleData)

    if not modelHash or modelHash == 0 or not IsModelInCdimage(modelHash) or not IsModelAVehicle(modelHash) then
        sendRetrievalSpawnResult(retrievalRequestId, false, 'invalid_model')
        TriggerEvent('lsrp_policevehicleparking:client:notify', 'Vehicle retrieval failed: vehicle model is unavailable', 'error')
        return
    end

    RequestModel(modelHash)
    local modelLoadTimeoutAt = GetGameTimer() + 7000
    while not HasModelLoaded(modelHash) and GetGameTimer() < modelLoadTimeoutAt do
        Wait(10)
    end

    if not HasModelLoaded(modelHash) then
        sendRetrievalSpawnResult(retrievalRequestId, false, 'model_load_timeout')
        TriggerEvent('lsrp_policevehicleparking:client:notify', 'Vehicle retrieval failed: model loading timed out', 'error')
        return
    end

    local vehicle = 0
    local spawnCandidates = {}
    if type(zoneCfg.spawnPoints) == 'table' and #zoneCfg.spawnPoints > 0 then
        for _, spawnPoint in ipairs(zoneCfg.spawnPoints) do
            if spawnPoint.coords then
                spawnCandidates[#spawnCandidates + 1] = {
                    coords = spawnPoint.coords,
                    heading = tonumber(spawnPoint.heading) or zoneRotation
                }
            end
        end
    else
        local spawnOffsets = {
            vector3(5.0, 5.0, 0.0),
            vector3(-5.0, 5.0, 0.0),
            vector3(5.0, -5.0, 0.0),
            vector3(-5.0, -5.0, 0.0),
            vector3(0.0, 8.0, 0.0)
        }

        for _, offset in ipairs(spawnOffsets) do
            spawnCandidates[#spawnCandidates + 1] = {
                coords = zoneCoords + offset,
                heading = zoneRotation
            }
        end
    end

    for _, spawnCandidate in ipairs(spawnCandidates) do
        local spawnCoords = spawnCandidate.coords
        local candidate = CreateVehicle(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCandidate.heading, true, false)
        if candidate ~= 0 and DoesEntityExist(candidate) then
            vehicle = candidate
            break
        end
    end

    SetModelAsNoLongerNeeded(modelHash)

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        sendRetrievalSpawnResult(retrievalRequestId, false, 'create_vehicle_failed')
        TriggerEvent('lsrp_policevehicleparking:client:notify', 'Vehicle retrieval failed: no clear spawn point found', 'error')
        return
    end

    SetVehicleOnGroundProperly(vehicle)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    setOwnedVehicleState(vehicle, vehicleData.id, vehicleData.ownerLicense, vehicleData.ownerStateId)
    disableVehicleRadio(vehicle)

    if vehicleData and type(vehicleData.plate) == 'string' and vehicleData.plate ~= '' then
        SetVehicleNumberPlateText(vehicle, vehicleData.plate)
    end

    if vehicleData and vehicleData.props then
        setVehicleProperties(vehicle, vehicleData.props)
    end

    TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
    Wait(0)
    disableVehicleRadio(vehicle)

    sendRetrievalSpawnResult(retrievalRequestId, true)

    Wait(500)
    if currentZone and currentZone.name == zoneName then
        TriggerServerEvent('lsrp_policevehicleparking:server:getParkedVehicles', currentZone.name)
    end

    closeParkingUI()
end)

RegisterNetEvent('lsrp_policevehicleparking:client:notify', function(message, type)
    if GetResourceState('lsrp_framework') == 'started' then
        exports['lsrp_framework']:notify(message, type)
        return
    end

    BeginTextCommandThefeedPost("STRING")
    AddTextComponentString(message)
    EndTextCommandThefeedPostTicker(false, true)
end)

RegisterNetEvent('lsrp_policevehicleparking:client:setWaypointToZone', function(zoneName)
    local zoneCfg = getParkingZoneByName(zoneName)

    if not zoneCfg then
        TriggerEvent('lsrp_policevehicleparking:client:notify', 'Parking location not found', 'error')
        return
    end

    SetNewWaypoint(zoneCfg.coords.x + 0.0, zoneCfg.coords.y + 0.0)
    TriggerEvent('lsrp_policevehicleparking:client:notify', ('GPS set to %s'):format(zoneCfg.name), 'success')
end)

RegisterNetEvent('lsrp_policevehicleparking:client:openParkingForZone', function(payload)
    local zoneName = type(payload) == 'table' and payload.zoneName or payload
    openParkingZoneByName(zoneName)
end)

RegisterCommand(VEHICLE_STORAGE_COMMAND_NAME, function()
    requestOpenVehicleStorage(true)
end, false)

RegisterCommand(VEHICLE_STORAGE_KEYMAP_COMMAND, function()
    requestOpenVehicleStorage(true)
end, false)

RegisterCommand(VEHICLE_STORAGE_KEYMAP_RELEASE_COMMAND, function()
    -- Required for RegisterKeyMapping.
end, false)

RegisterKeyMapping(VEHICLE_STORAGE_KEYMAP_COMMAND, 'Open nearby emergency vehicle storage', 'keyboard', trimString(getVehicleStorageConfig().defaultKey) or 'G')

print(('^2[%s]^7 Client script loaded successfully'):format(RESOURCE_NAME))
