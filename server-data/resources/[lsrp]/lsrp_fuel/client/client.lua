local refuelRequestCounter = 0
local pendingRefuelRequests = {}
local refuelInProgress = false
local modelTankCapacityCache = {}
local hudState = {
    visible = false,
    fuelLevel = 0.0,
    tankCapacity = 0.0,
    fuelPercent = 0.0,
    vehicleName = '',
    isLow = false,
    isCritical = false
}
local lastHudSnapshot = nil

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

local function clampTankCapacity(value)
    local minimumCapacity = math.max(1.0, tonumber(Config.MinTankCapacity) or 5.0)
    local maximumCapacity = math.max(minimumCapacity, tonumber(Config.MaxTankCapacity) or tonumber(Config.DefaultTankCapacity) or 65.0)
    local tankCapacity = tonumber(value) or tonumber(Config.DefaultTankCapacity) or 65.0

    tankCapacity = math.max(minimumCapacity, math.min(maximumCapacity, tankCapacity))
    return tankCapacity + 0.0
end

local function clampFuelLevel(value, maxFuel)
    local fuelLevel = tonumber(value) or 0.0
    fuelLevel = math.max(0.0, math.min(clampTankCapacity(maxFuel), fuelLevel))
    return fuelLevel + 0.0
end

local function roundFuelValue(value)
    local numericValue = tonumber(value) or 0.0
    return math.floor((numericValue * 10.0) + 0.5) / 10.0
end

local function formatCurrency(amount)
    if GetResourceState('lsrp_economy') == 'started' then
        local ok, formatted = pcall(function()
            return exports['lsrp_economy']:formatCurrency(amount)
        end)

        if ok and type(formatted) == 'string' and formatted ~= '' then
            return formatted
        end
    end

    local value = math.max(0, math.floor(tonumber(amount) or 0))
    local formatted = tostring(value)

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
    EndTextCommandThefeedPostTicker(false, false)
end

local function showHelpPrompt(message)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(tostring(message or ''))
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function getVehicleTankCapacity(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return clampTankCapacity(nil)
    end

    local modelHash = GetEntityModel(vehicle)
    if modelHash and modelHash ~= 0 and modelTankCapacityCache[modelHash] then
        return modelTankCapacityCache[modelHash]
    end

    local tankCapacity = nil
    if type(GetVehicleHandlingFloat) == 'function' then
        local ok, value = pcall(GetVehicleHandlingFloat, vehicle, 'CHandlingData', 'fPetrolTankVolume')
        if ok then
            tankCapacity = tonumber(value)
        end
    end

    tankCapacity = clampTankCapacity(tankCapacity)

    if modelHash and modelHash ~= 0 then
        modelTankCapacityCache[modelHash] = tankCapacity
    end

    return tankCapacity
end

local function getFuelPercent(fuelLevel, tankCapacity)
    local normalizedTankCapacity = math.max(0.1, clampTankCapacity(tankCapacity))
    return math.max(0.0, math.min(100.0, (clampFuelLevel(fuelLevel, normalizedTankCapacity) / normalizedTankCapacity) * 100.0))
end

local function isFuelManagedVehicle(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return false
    end

    local vehicleClass = GetVehicleClass(vehicle)
    return not (Config.DisabledVehicleClasses and Config.DisabledVehicleClasses[vehicleClass] == true)
end

local function getVehicleDisplayName(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return 'vehicle'
    end

    local modelHash = GetEntityModel(vehicle)
    if not modelHash or modelHash == 0 then
        return 'vehicle'
    end

    local displayCode = trimString(GetDisplayNameFromVehicleModel(modelHash))
    if displayCode and displayCode ~= 'CARNOTFOUND' then
        local labelText = trimString(GetLabelText(displayCode))
        if labelText and labelText ~= 'NULL' then
            return labelText
        end

        return displayCode:gsub('[_%-]+', ' ')
    end

    return 'vehicle'
end

local function getStateFuel(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return nil
    end

    local entityState = Entity(vehicle).state
    local stateFuel = entityState and entityState.lsrpFuelLevel

    if type(stateFuel) == 'number' then
        return clampFuelLevel(stateFuel, getVehicleTankCapacity(vehicle))
    end

    return nil
end

local function setVehicleFuelLevelSafe(vehicle, fuelLevel, replicate)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return nil
    end

    local tankCapacity = getVehicleTankCapacity(vehicle)
    local clampedFuel = clampFuelLevel(fuelLevel, tankCapacity)
    SetVehicleFuelLevel(vehicle, clampedFuel)

    local entityState = Entity(vehicle).state
    if entityState then
        local tolerance = tonumber(Config.SyncTolerance) or 0.2
        local stateFuel = tonumber(entityState.lsrpFuelLevel)
        local stateCapacity = tonumber(entityState.lsrpFuelCapacity)

        if stateFuel == nil or math.abs(stateFuel - clampedFuel) > tolerance then
            entityState:set('lsrpFuelLevel', clampedFuel, replicate == true)
        end

        if stateCapacity == nil or math.abs(stateCapacity - tankCapacity) > tolerance then
            entityState:set('lsrpFuelCapacity', tankCapacity, replicate == true)
        end
    end

    return clampedFuel
end

local function getVehicleFuelLevelSafe(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) or not isFuelManagedVehicle(vehicle) then
        return nil
    end

    local tankCapacity = getVehicleTankCapacity(vehicle)
    local stateFuel = getStateFuel(vehicle)
    if stateFuel ~= nil then
        local nativeFuel = clampFuelLevel(GetVehicleFuelLevel(vehicle), tankCapacity)
        if math.abs(nativeFuel - stateFuel) > (tonumber(Config.SyncTolerance) or 0.2) then
            SetVehicleFuelLevel(vehicle, stateFuel)
        end

        return stateFuel
    end

    local nativeFuel = clampFuelLevel(GetVehicleFuelLevel(vehicle), tankCapacity)
    return setVehicleFuelLevelSafe(vehicle, nativeFuel, true)
end

local function stopVehicleWhenOutOfFuel(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return
    end

    SetVehicleEngineOn(vehicle, false, true, true)
    SetVehicleUndriveable(vehicle, true)

    CreateThread(function()
        Wait(150)
        if DoesEntityExist(vehicle) then
            SetVehicleUndriveable(vehicle, false)
        end
    end)
end

local function getConsumptionMultiplier(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return 1.0
    end

    local vehicleClass = GetVehicleClass(vehicle)
    if Config.ClassUsageMultiplier and Config.ClassUsageMultiplier[vehicleClass] then
        return tonumber(Config.ClassUsageMultiplier[vehicleClass]) or 1.0
    end

    return 1.0
end

local function getFuelNeeded(vehicle)
    local fuelLevel = getVehicleFuelLevelSafe(vehicle)
    if fuelLevel == nil then
        return 0.0
    end

    return math.max(0.0, getVehicleTankCapacity(vehicle) - fuelLevel)
end

local function buildHudSnapshot(payload)
    if not payload or payload.visible ~= true then
        return 'hidden'
    end

    return table.concat({
        tostring(payload.vehicleName or ''),
        ('%.1f'):format(tonumber(payload.fuelLevel) or 0.0),
        ('%.1f'):format(tonumber(payload.tankCapacity) or 0.0),
        ('%.1f'):format(tonumber(payload.fuelPercent) or 0.0),
        payload.isLow and '1' or '0',
        payload.isCritical and '1' or '0'
    }, '|')
end

local function sendFuelHud(payload)
    local message = payload or {
        visible = false,
        fuelLevel = 0.0,
        tankCapacity = 0.0,
        fuelPercent = 0.0,
        vehicleName = '',
        isLow = false,
        isCritical = false
    }

    local snapshot = buildHudSnapshot(message)
    if snapshot == lastHudSnapshot then
        return
    end

    lastHudSnapshot = snapshot
    hudState.visible = message.visible == true
    hudState.fuelLevel = roundFuelValue(message.fuelLevel)
    hudState.tankCapacity = roundFuelValue(message.tankCapacity)
    hudState.fuelPercent = roundFuelValue(message.fuelPercent)
    hudState.vehicleName = tostring(message.vehicleName or '')
    hudState.isLow = message.isLow == true
    hudState.isCritical = message.isCritical == true
end

local function hideFuelHud()
    sendFuelHud(nil)
end

local function getFuelHudPalette()
    if hudState.isCritical then
        return 238, 63, 79
    end

    if hudState.isLow then
        return 242, 109, 61
    end

    return 241, 182, 82
end

local function drawFuelHudRect(x, y, width, height, red, green, blue, alpha)
    DrawRect(x, y, width, height, red, green, blue, alpha)
end

local function drawFuelHudText(x, y, text, scale, red, green, blue, alpha, centered)
    SetTextScale(scale, scale)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(red, green, blue, alpha)
    SetTextOutline()
    SetTextCentre(centered == true)
    SetTextJustification(centered == true and 0 or 1)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

local function drawFuelHud()
    if hudState.visible ~= true then
        return
    end

    local safeZone = GetSafeZoneSize()
    local safeZoneOffset = (1.0 - safeZone) * 0.5
    local cardWidth = 0.132
    local cardHeight = 0.082
    local cardX = 1.0 - safeZoneOffset - (cardWidth * 0.5) - 0.018
    local cardY = 1.0 - safeZoneOffset - (cardHeight * 0.5) - 0.115
    local accentRed, accentGreen, accentBlue = getFuelHudPalette()
    local fuelPercent = math.max(0.0, math.min(100.0, tonumber(hudState.fuelPercent) or 0.0))
    local fillFraction = fuelPercent / 100.0
    local barWidth = cardWidth - 0.024
    local barHeight = 0.010
    local barX = cardX
    local barY = cardY + 0.018
    local fillWidth = barWidth * fillFraction

    drawFuelHudRect(cardX, cardY, cardWidth, cardHeight, 10, 14, 20, 178)
    drawFuelHudRect(cardX, cardY - 0.028, cardWidth, 0.0032, accentRed, accentGreen, accentBlue, 240)
    drawFuelHudRect(barX, barY, barWidth, barHeight, 28, 35, 46, 220)

    if fillWidth > 0.0005 then
        local fillX = (barX - (barWidth * 0.5)) + (fillWidth * 0.5)
        drawFuelHudRect(fillX, barY, fillWidth, barHeight * 0.72, accentRed, accentGreen, accentBlue, 235)
    end

    drawFuelHudText(cardX - 0.05, cardY - 0.031, hudState.vehicleName, 0.31, 244, 241, 236, 220, false)
    drawFuelHudText(cardX + 0.034, cardY - 0.031, ('%d%%'):format(math.floor(fuelPercent + 0.5)), 0.31, accentRed, accentGreen, accentBlue, 240, false)
    drawFuelHudText(cardX - 0.05, cardY - 0.002, ('%.1f / %.1fL'):format(hudState.fuelLevel, hudState.tankCapacity), 0.26, 235, 238, 241, 210, false)

    if hudState.isCritical then
        drawFuelHudText(cardX - 0.05, cardY + 0.023, 'CRITICAL RESERVE', 0.24, accentRed, accentGreen, accentBlue, 230, false)
    elseif hudState.isLow then
        drawFuelHudText(cardX - 0.05, cardY + 0.023, 'LOW RESERVE', 0.24, accentRed, accentGreen, accentBlue, 220, false)
    else
        drawFuelHudText(cardX - 0.05, cardY + 0.023, 'FUEL STABLE', 0.24, 190, 198, 207, 190, false)
    end
end

local function updateFuelHud(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) or not isFuelManagedVehicle(vehicle) then
        hideFuelHud()
        return
    end

    local fuelLevel = getVehicleFuelLevelSafe(vehicle)
    if fuelLevel == nil then
        hideFuelHud()
        return
    end

    local tankCapacity = getVehicleTankCapacity(vehicle)
    local fuelPercent = getFuelPercent(fuelLevel, tankCapacity)
    local lowFuelPercent = tonumber(Config.HudLowFuelPercent) or 15.0
    local criticalFuelPercent = tonumber(Config.HudCriticalFuelPercent) or 7.0

    sendFuelHud({
        visible = true,
        fuelLevel = fuelLevel,
        tankCapacity = tankCapacity,
        fuelPercent = fuelPercent,
        vehicleName = getVehicleDisplayName(vehicle),
        isLow = fuelPercent <= lowFuelPercent,
        isCritical = fuelPercent <= criticalFuelPercent
    })
end

local function quoteRefuelCost(units)
    local normalizedUnits = tonumber(units)
    if not normalizedUnits or normalizedUnits <= 0 then
        return nil
    end

    return math.max(1, math.ceil(normalizedUnits * (tonumber(Config.RefuelCostPerUnit) or 1)))
end

local function getNearestFuelPumpInteraction(playerCoords)
    local nearestPump = nil
    local scanRadius = tonumber(Config.PumpScanRadius or Config.PumpSearchRadius) or 5.0
    local interactDistance = tonumber(Config.PumpInteractDistance or Config.PumpSearchRadius) or 1.8
    local nearestDistance = interactDistance + 0.001

    for _, modelHash in ipairs(Config.PumpModels or {}) do
        local pump = GetClosestObjectOfType(playerCoords.x, playerCoords.y, playerCoords.z, scanRadius, modelHash, false, false, false)
        if pump ~= 0 and DoesEntityExist(pump) then
            local pumpCoords = GetEntityCoords(pump)
            local distance = #(playerCoords - pumpCoords)

            if distance <= interactDistance and distance < nearestDistance then
                nearestDistance = distance
                nearestPump = {
                    entity = pump,
                    coords = pumpCoords,
                    distance = distance
                }
            end
        end
    end

    return nearestPump
end

local function getClosestFuelVehicle(originCoords, maxDistance)
    local closestVehicle = 0
    local closestDistance = (tonumber(maxDistance) or tonumber(Config.VehicleSearchRadius) or 4.0) + 0.001

    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) and isFuelManagedVehicle(vehicle) then
            local vehicleCoords = GetEntityCoords(vehicle)
            local distance = #(originCoords - vehicleCoords)

            if distance <= closestDistance then
                closestDistance = distance
                closestVehicle = vehicle
            end
        end
    end

    return closestVehicle, closestDistance
end

local function disableRefuelControls()
    DisableControlAction(0, 21, true)
    DisableControlAction(0, 22, true)
    DisableControlAction(0, 23, true)
    DisableControlAction(0, 24, true)
    DisableControlAction(0, 25, true)
    DisableControlAction(0, 30, true)
    DisableControlAction(0, 31, true)
    DisableControlAction(0, 32, true)
    DisableControlAction(0, 33, true)
    DisableControlAction(0, 34, true)
    DisableControlAction(0, 35, true)
    DisableControlAction(0, 44, true)
    DisableControlAction(0, 75, true)
    DisableControlAction(0, 140, true)
    DisableControlAction(0, 141, true)
    DisableControlAction(0, 142, true)
    DisableControlAction(0, 63, true)
    DisableControlAction(0, 64, true)
    DisableControlAction(0, 71, true)
    DisableControlAction(0, 72, true)
end

local function beginRefuel(vehicle, purchasedFuelUnits, totalCost)
    if refuelInProgress then
        return
    end

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        notify('Refuel failed: vehicle is no longer available.')
        return
    end

    local currentFuel = getVehicleFuelLevelSafe(vehicle)
    if currentFuel == nil then
        notify('Refuel failed: vehicle fuel data is unavailable.')
        return
    end

    local targetFuel = clampFuelLevel(currentFuel + (tonumber(purchasedFuelUnits) or 0.0), getVehicleTankCapacity(vehicle))
    local durationMs = math.max(750, math.floor((tonumber(purchasedFuelUnits) or 1.0) * (tonumber(Config.RefuelDurationMsPerUnit) or 80)))
    local vehicleName = getVehicleDisplayName(vehicle)

    refuelInProgress = true

    CreateThread(function()
        local ped = PlayerPedId()
        TaskTurnPedToFaceEntity(ped, vehicle, durationMs)
        SetVehicleEngineOn(vehicle, false, true, true)

        local endAt = GetGameTimer() + durationMs

        while GetGameTimer() < endAt do
            disableRefuelControls()
            showHelpPrompt(('Refueling %s...'):format(vehicleName))
            Wait(0)
        end

        if DoesEntityExist(vehicle) then
            setVehicleFuelLevelSafe(vehicle, targetFuel, true)
            notify(('Refueled %s for %s.'):format(vehicleName, formatCurrency(totalCost)))
        else
            notify('Refuel completed, but the vehicle is no longer nearby.')
        end

        refuelInProgress = false
    end)
end

local function requestRefuel(vehicle)
    if refuelInProgress or vehicle == 0 or not DoesEntityExist(vehicle) then
        return
    end

    local fuelNeeded = getFuelNeeded(vehicle)
    if fuelNeeded <= (tonumber(Config.EmptyFuelThreshold) or 0.1) then
        notify(('The %s tank is already full.'):format(getVehicleDisplayName(vehicle)))
        return
    end

    refuelRequestCounter = refuelRequestCounter + 1
    pendingRefuelRequests[refuelRequestCounter] = vehicle
    TriggerServerEvent('lsrp_fuel:server:requestRefuel', refuelRequestCounter, fuelNeeded)
end

RegisterNetEvent('lsrp_fuel:client:refuelApproved', function(requestId, purchasedFuelUnits, totalCost)
    local normalizedRequestId = tonumber(requestId)
    local vehicle = normalizedRequestId and pendingRefuelRequests[normalizedRequestId]

    if normalizedRequestId then
        pendingRefuelRequests[normalizedRequestId] = nil
    end

    if not vehicle then
        return
    end

    beginRefuel(vehicle, purchasedFuelUnits, totalCost)
end)

RegisterNetEvent('lsrp_fuel:client:refuelDenied', function(requestId, message)
    local normalizedRequestId = tonumber(requestId)
    if normalizedRequestId then
        pendingRefuelRequests[normalizedRequestId] = nil
    end

    notify(message or 'Fuel purchase was declined.')
end)

CreateThread(function()
    while true do
        local waitMs = math.max(250, tonumber(Config.ConsumptionTickMs) or 1000)
        local ped = PlayerPedId()

        if ped ~= 0 and DoesEntityExist(ped) and IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)

            if vehicle ~= 0 and isFuelManagedVehicle(vehicle) then
                local fuelLevel = getVehicleFuelLevelSafe(vehicle)
                if fuelLevel ~= nil and GetPedInVehicleSeat(vehicle, -1) == ped and GetIsVehicleEngineRunning(vehicle) then
                    local rpm = math.max(0.2, tonumber(GetVehicleCurrentRpm(vehicle)) or 0.0)
                    local speedMultiplier = 1.0
                        + math.min((GetEntitySpeed(vehicle) * 3.6) / 140.0, 1.0)
                        * (tonumber(Config.SpeedUsageMultiplier) or 0.35)
                    local delta = (tonumber(Config.BaseUsagePerSecond) or 0.12)
                        * rpm
                        * speedMultiplier
                        * getConsumptionMultiplier(vehicle)
                        * (waitMs / 1000.0)

                    local nextFuelLevel = setVehicleFuelLevelSafe(vehicle, fuelLevel - delta, true)
                    if nextFuelLevel and nextFuelLevel <= (tonumber(Config.EmptyFuelThreshold) or 0.1) then
                        stopVehicleWhenOutOfFuel(vehicle)
                    end
                end
            end
        end

        Wait(waitMs)
    end
end)

CreateThread(function()
    while true do
        local waitMs = 750

        if not refuelInProgress then
            local ped = PlayerPedId()
            if ped ~= 0 and DoesEntityExist(ped) then
                local playerCoords = GetEntityCoords(ped)
                local pumpInteraction = getNearestFuelPumpInteraction(playerCoords)

                if pumpInteraction then
                    waitMs = 0

                    local vehicle = 0
                    local seatedVehicle = 0

                    if IsPedInAnyVehicle(ped, false) then
                        seatedVehicle = GetVehiclePedIsIn(ped, false)
                    end

                    if seatedVehicle ~= 0
                        and DoesEntityExist(seatedVehicle)
                        and isFuelManagedVehicle(seatedVehicle)
                        and GetPedInVehicleSeat(seatedVehicle, -1) == ped
                    then
                        local seatedVehicleCoords = GetEntityCoords(seatedVehicle)
                        local seatedDistance = #(seatedVehicleCoords - pumpInteraction.coords)
                        if seatedDistance <= (tonumber(Config.PumpVehicleDistance) or tonumber(Config.VehicleSearchRadius) or 4.0) then
                            vehicle = seatedVehicle
                        end
                    end

                    if vehicle == 0 then
                        vehicle = getClosestFuelVehicle(
                            pumpInteraction.coords,
                            tonumber(Config.PumpVehicleDistance) or tonumber(Config.VehicleSearchRadius) or 4.0
                        )
                    end

                    if vehicle == 0 or not DoesEntityExist(vehicle) then
                        showHelpPrompt('Bring a vehicle next to the pump to refuel.')
                    else
                        local vehicleName = getVehicleDisplayName(vehicle)
                        local driver = GetPedInVehicleSeat(vehicle, -1)
                        local fuelNeeded = getFuelNeeded(vehicle)
                        local playerIsDriver = driver == ped

                        if fuelNeeded <= (tonumber(Config.EmptyFuelThreshold) or 0.1) then
                            showHelpPrompt(('The %s tank is already full.'):format(vehicleName))
                        elseif driver ~= 0 and not playerIsDriver then
                            showHelpPrompt(('The %s must be unoccupied to refuel.'):format(vehicleName))
                        elseif GetIsVehicleEngineRunning(vehicle) then
                            showHelpPrompt(('Turn the %s engine off before refueling.'):format(vehicleName))
                        else
                            local totalCost = quoteRefuelCost(fuelNeeded)
                            showHelpPrompt(('Press ~INPUT_CONTEXT~ to refuel %s for %s.'):format(vehicleName, formatCurrency(totalCost or 0)))

                            if IsControlJustPressed(0, tonumber(Config.RefuelControl) or 38) then
                                requestRefuel(vehicle)
                            end
                        end
                    end
                end
            end
        end

        Wait(waitMs)
    end
end)

CreateThread(function()
    while true do
        local waitMs = math.max(150, tonumber(Config.HudUpdateMs) or 150)
        local ped = PlayerPedId()

        if IsPauseMenuActive() then
            hideFuelHud()
            waitMs = 500
        elseif ped ~= 0 and DoesEntityExist(ped) and IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)

            if vehicle ~= 0 and DoesEntityExist(vehicle) and isFuelManagedVehicle(vehicle) then
                updateFuelHud(vehicle)
            else
                hideFuelHud()
                waitMs = 500
            end
        else
            hideFuelHud()
            waitMs = 500
        end

        Wait(waitMs)
    end
end)

CreateThread(function()
    while true do
        if hudState.visible == true and not IsPauseMenuActive() then
            drawFuelHud()
            Wait(0)
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    hideFuelHud()
    refuelInProgress = false
    pendingRefuelRequests = {}
    modelTankCapacityCache = {}
    hudState = {
        visible = false,
        fuelLevel = 0.0,
        tankCapacity = 0.0,
        fuelPercent = 0.0,
        vehicleName = '',
        isLow = false,
        isCritical = false
    }
    lastHudSnapshot = nil
end)

exports('getFuel', function(vehicle)
    return getVehicleFuelLevelSafe(vehicle)
end)

exports('setFuel', function(vehicle, fuelLevel)
    return setVehicleFuelLevelSafe(vehicle, fuelLevel, true)
end)

exports('addFuel', function(vehicle, fuelDelta)
    local currentFuel = getVehicleFuelLevelSafe(vehicle)
    if currentFuel == nil then
        return nil
    end

    return setVehicleFuelLevelSafe(vehicle, currentFuel + (tonumber(fuelDelta) or 0.0), true)
end)

exports('isRefueling', function()
    return refuelInProgress
end)