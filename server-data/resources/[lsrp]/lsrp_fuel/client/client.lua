local refuelRequestCounter = 0
local pendingRefuelRequests = {}
local refuelInProgress = false
local modelTankCapacityCache = {}
local refuelProgressState = {
    visible = false,
    label = '',
    progress = 0.0,
    totalCost = 0,
    liters = 0.0
}

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

local function snapFuelLevelToCapacity(value, tankCapacity)
    local normalizedCapacity = clampTankCapacity(tankCapacity)
    local fuelLevel = clampFuelLevel(value, normalizedCapacity)
    local snapTolerance = math.max(0.01, tonumber(Config.FullTankSnapTolerance) or 0.25)

    if (normalizedCapacity - fuelLevel) <= snapTolerance then
        return normalizedCapacity
    end

    return fuelLevel
end

local function getNativeDriveFuelFloor(tankCapacity)
    local normalizedTankCapacity = clampTankCapacity(tankCapacity)
    local floorPercent = math.max(0.0, tonumber(Config.NativeFuelDriveFloorPercent) or 10.0)
    local floorAbsolute = math.max(0.0, tonumber(Config.NativeFuelDriveFloorAbsolute) or 0.0)
    local floorByPercent = normalizedTankCapacity * (floorPercent / 100.0)
    return math.min(normalizedTankCapacity, math.max(floorAbsolute, floorByPercent))
end

local function getNativeFuelLevelForVehicle(logicalFuelLevel, tankCapacity)
    local normalizedTankCapacity = clampTankCapacity(tankCapacity)
    local logicalFuel = clampFuelLevel(logicalFuelLevel, normalizedTankCapacity)
    if logicalFuel <= 0.0 then
        return 0.0
    end

    return math.max(logicalFuel, getNativeDriveFuelFloor(normalizedTankCapacity))
end

local function requestVehicleControl(vehicle, timeoutMs)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return false
    end

    if not NetworkGetEntityIsNetworked(vehicle) then
        return true
    end

    if NetworkHasControlOfEntity(vehicle) then
        return true
    end

    local timeoutAt = GetGameTimer() + (timeoutMs or 500)
    NetworkRequestControlOfEntity(vehicle)

    while GetGameTimer() < timeoutAt do
        if NetworkHasControlOfEntity(vehicle) then
            return true
        end

        Wait(0)
        NetworkRequestControlOfEntity(vehicle)
    end

    return NetworkHasControlOfEntity(vehicle)
end

local function requestAnimDictLoaded(animDict)
    local normalizedAnimDict = trimString(animDict)
    if not normalizedAnimDict then
        return false
    end

    RequestAnimDict(normalizedAnimDict)
    local timeoutAt = GetGameTimer() + 5000
    while not HasAnimDictLoaded(normalizedAnimDict) do
        if GetGameTimer() >= timeoutAt then
            return false
        end

        Wait(0)
    end

    return true
end

local function getRefuelAnimationConfig()
    local animationMode = trimString(Config and Config.RefuelAnimationMode)
    if animationMode == 'anim' then
        local animDict = trimString(Config and Config.RefuelAnimationDict)
        local animName = trimString(Config and Config.RefuelAnimationName)
        if animDict and animName then
            return {
                mode = 'anim',
                dict = animDict,
                name = animName,
                flag = math.floor(tonumber(Config and Config.RefuelAnimationFlag) or 1)
            }
        end
    end

    local scenarioName = trimString(Config and Config.RefuelAnimationScenario)
    if not scenarioName then
        scenarioName = 'WORLD_HUMAN_VEHICLE_MECHANIC'
    end

    return {
        mode = 'scenario',
        scenario = scenarioName
    }
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
    local currentFuel = getStateFuel(vehicle) or clampFuelLevel(GetVehicleFuelLevel(vehicle), tankCapacity)
    local clampedFuel = clampFuelLevel(fuelLevel, tankCapacity)
    local nativeFuelLevel = getNativeFuelLevelForVehicle(clampedFuel, tankCapacity)

    if clampedFuel >= currentFuel then
        clampedFuel = snapFuelLevelToCapacity(clampedFuel, tankCapacity)
        nativeFuelLevel = getNativeFuelLevelForVehicle(clampedFuel, tankCapacity)
    end

    requestVehicleControl(vehicle, 500)
    SetVehicleFuelLevel(vehicle, nativeFuelLevel)

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
    local nativeFuel = clampFuelLevel(GetVehicleFuelLevel(vehicle), tankCapacity)
    if stateFuel ~= nil then
        local tolerance = tonumber(Config.SyncTolerance) or 0.2
        local nativeDriveFuelFloor = getNativeDriveFuelFloor(tankCapacity)
        local desiredNativeFuel = getNativeFuelLevelForVehicle(stateFuel, tankCapacity)

        -- Prefer the local native value while fuel is decreasing so stale replicated
        -- state does not snap the tank back up between sync updates.
        if nativeFuel > (nativeDriveFuelFloor + tolerance) and nativeFuel < stateFuel then
            return nativeFuel
        end

        if math.abs(nativeFuel - desiredNativeFuel) > tolerance then
            requestVehicleControl(vehicle, 500)
            SetVehicleFuelLevel(vehicle, desiredNativeFuel)
        end

        return stateFuel
    end

    return setVehicleFuelLevelSafe(vehicle, nativeFuel, true)
end

local function stopVehicleWhenOutOfFuel(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return
    end

    if not GetIsVehicleEngineRunning(vehicle) then
        return
    end

    SetVehicleEngineOn(vehicle, false, true, true)
end

local function isFuelExhausted(fuelLevel)
    return (tonumber(fuelLevel) or 0.0) <= 0.0
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

local function setRefuelProgressVisible(visible, label, progress, totalCost, liters)
    refuelProgressState.visible = visible == true
    refuelProgressState.label = tostring(label or '')
    refuelProgressState.progress = math.max(0.0, math.min(1.0, tonumber(progress) or 0.0))
    refuelProgressState.totalCost = math.max(0, math.floor(tonumber(totalCost) or 0))
    refuelProgressState.liters = math.max(0.0, tonumber(liters) or 0.0)
end

local function hideRefuelProgress()
    setRefuelProgressVisible(false, '', 0.0, 0, 0.0)
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

local function drawRefuelProgress()
    if refuelProgressState.visible ~= true then
        return
    end

    local safeZone = GetSafeZoneSize()
    local safeZoneOffset = (1.0 - safeZone) * 0.5
    local cardWidth = 0.19
    local cardHeight = 0.062
    local cardX = 0.5
    local cardY = 1.0 - safeZoneOffset - (cardHeight * 0.5) - 0.045
    local barWidth = cardWidth - 0.02
    local barHeight = 0.012
    local barY = cardY + 0.012
    local progress = math.max(0.0, math.min(1.0, refuelProgressState.progress))
    local fillWidth = barWidth * progress

    drawFuelHudRect(cardX, cardY, cardWidth, cardHeight, 9, 16, 24, 205)
    drawFuelHudText(cardX, cardY - 0.018, refuelProgressState.label ~= '' and refuelProgressState.label or 'Refueling vehicle', 0.31, 244, 241, 236, 225, true)
    drawFuelHudText(cardX, cardY - 0.001, ('%d%%  |  %.1fL  |  %s'):format(math.floor((progress * 100.0) + 0.5), refuelProgressState.liters, formatCurrency(refuelProgressState.totalCost)), 0.24, 214, 221, 228, 215, true)
    drawFuelHudRect(cardX, barY, barWidth, barHeight, 24, 33, 42, 225)

    if fillWidth > 0.0005 then
        local fillX = (cardX - (barWidth * 0.5)) + (fillWidth * 0.5)
        drawFuelHudRect(fillX, barY, fillWidth, barHeight * 0.72, 74, 181, 116, 235)
    end
end

local function startRefuelAnimation(ped, vehicle)
    if ped == 0 or not DoesEntityExist(ped) then
        return
    end

    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        TaskTurnPedToFaceEntity(ped, vehicle, 1200)
        Wait(250)
    end

    local animationConfig = getRefuelAnimationConfig()
    if animationConfig.mode == 'anim' then
        if requestAnimDictLoaded(animationConfig.dict) then
            TaskPlayAnim(ped, animationConfig.dict, animationConfig.name, 8.0, 1.0, -1, animationConfig.flag, 0.0, false, false, false)
            return
        end
    end

    TaskStartScenarioInPlace(ped, animationConfig.scenario, 0, true)
end

local function stopRefuelAnimation(ped)
    if ped == 0 or not DoesEntityExist(ped) then
        return
    end

    ClearPedTasks(ped)
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

local function ensurePedReadyForRefuel(ped, vehicle)
    if ped == 0 or not DoesEntityExist(ped) then
        return false
    end

    if IsPedInAnyVehicle(ped, false) then
        if vehicle == 0 or not DoesEntityExist(vehicle) or GetVehiclePedIsIn(ped, false) ~= vehicle or GetPedInVehicleSeat(vehicle, -1) ~= ped then
            return false
        end

        TaskLeaveVehicle(ped, vehicle, 0)

        local timeoutAt = GetGameTimer() + 4000
        while IsPedInAnyVehicle(ped, false) and GetGameTimer() < timeoutAt do
            disableRefuelControls()
            Wait(0)
        end

        if IsPedInAnyVehicle(ped, false) then
            return false
        end
    end

    return true
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

    local tankCapacity = getVehicleTankCapacity(vehicle)
    local targetFuel = clampFuelLevel(currentFuel + (tonumber(purchasedFuelUnits) or 0.0), tankCapacity)
    local litersAdded = math.max(0.0, targetFuel - currentFuel)
    if litersAdded <= 0.0 then
        notify(('The %s tank is already full.'):format(getVehicleDisplayName(vehicle)))
        return
    end

    local fillFraction = litersAdded / math.max(0.1, tankCapacity)
    local durationMs = math.max(
        math.floor(tonumber(Config.MinRefuelDurationMs) or 1500),
        math.floor((tonumber(Config.FullRefuelDurationMs) or 60000) * fillFraction)
    )
    local vehicleName = getVehicleDisplayName(vehicle)

    refuelInProgress = true
    hideRefuelProgress()

    CreateThread(function()
        local ped = PlayerPedId()
        if not ensurePedReadyForRefuel(ped, vehicle) then
            refuelInProgress = false
            notify('Exit the vehicle to start refueling.')
            return
        end

        if not DoesEntityExist(vehicle) then
            refuelInProgress = false
            notify('Refuel failed: vehicle is no longer available.')
            return
        end

        SetVehicleEngineOn(vehicle, false, true, true)
        startRefuelAnimation(ped, vehicle)

        local endAt = GetGameTimer() + durationMs

        while GetGameTimer() < endAt do
            if not DoesEntityExist(vehicle) then
                break
            end

            disableRefuelControls()

            if not IsEntityPlayingAnim(ped, trimString(Config and Config.RefuelAnimationDict) or '', trimString(Config and Config.RefuelAnimationName) or '', 3)
                and not IsPedActiveInScenario(ped)
            then
                startRefuelAnimation(ped, vehicle)
            end

            local remainingMs = math.max(0, endAt - GetGameTimer())
            local progress = 1.0 - (remainingMs / math.max(1, durationMs))
            local currentRefuelFuel = currentFuel + (litersAdded * progress)

            setVehicleFuelLevelSafe(vehicle, currentRefuelFuel, true)
            setRefuelProgressVisible(true, ('Refueling %s'):format(vehicleName), progress, totalCost, litersAdded)
            showHelpPrompt(('Refueling %s...'):format(vehicleName))
            Wait(0)
        end

        stopRefuelAnimation(ped)
        hideRefuelProgress()

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
                    local speedKmh = math.max(0.0, GetEntitySpeed(vehicle) * 3.6)
                    local baseUsagePerSecond = tonumber(Config.BaseUsagePerSecond) or 0.12
                    local classMultiplier = getConsumptionMultiplier(vehicle)
                    local idleSpeedThresholdKmh = math.max(0.0, tonumber(Config.IdleSpeedThresholdKmh) or 1.0)
                    local delta = 0.0

                    if speedKmh <= idleSpeedThresholdKmh then
                        delta = baseUsagePerSecond
                            * math.max(0.0, tonumber(Config.IdleUsageMultiplier) or 0.1)
                            * classMultiplier
                            * (waitMs / 1000.0)
                    else
                        local rpm = math.max(0.2, tonumber(GetVehicleCurrentRpm(vehicle)) or 0.0)
                        local speedMultiplier = 1.0
                            + math.min(speedKmh / 140.0, 1.0)
                            * (tonumber(Config.SpeedUsageMultiplier) or 0.35)

                        delta = baseUsagePerSecond
                            * rpm
                            * speedMultiplier
                            * classMultiplier
                            * (waitMs / 1000.0)
                    end

                    local nextFuelLevel = setVehicleFuelLevelSafe(vehicle, fuelLevel - delta, true)
                    if isFuelExhausted(nextFuelLevel) then
                        stopVehicleWhenOutOfFuel(vehicle)
                    end
                end
            end
        end

        -- Also consume fuel for any nearby/streamed vehicles whose engine is running
        -- even if the player is not currently seated in them. This ensures engines
        -- continue to consume while left running.
        local processed = {}
        if ped ~= 0 and DoesEntityExist(ped) and IsPedInAnyVehicle(ped, false) then
            local pveh = GetVehiclePedIsIn(ped, false)
            if pveh ~= 0 then
                processed[pveh] = true
            end
        end

        for _, vehicle in ipairs(GetGamePool('CVehicle')) do
            if vehicle ~= 0 and DoesEntityExist(vehicle) and not processed[vehicle] and isFuelManagedVehicle(vehicle) and GetIsVehicleEngineRunning(vehicle) then
                local fuelLevel = getVehicleFuelLevelSafe(vehicle)
                if fuelLevel ~= nil then
                    local speedKmh = math.max(0.0, GetEntitySpeed(vehicle) * 3.6)
                    local baseUsagePerSecond = tonumber(Config.BaseUsagePerSecond) or 0.12
                    local classMultiplier = getConsumptionMultiplier(vehicle)
                    local idleSpeedThresholdKmh = math.max(0.0, tonumber(Config.IdleSpeedThresholdKmh) or 1.0)
                    local delta = 0.0

                    if speedKmh <= idleSpeedThresholdKmh then
                        delta = baseUsagePerSecond
                            * math.max(0.0, tonumber(Config.IdleUsageMultiplier) or 0.1)
                            * classMultiplier
                            * (waitMs / 1000.0)
                    else
                        local rpm = math.max(0.2, tonumber(GetVehicleCurrentRpm(vehicle)) or 0.0)
                        local speedMultiplier = 1.0
                            + math.min(speedKmh / 140.0, 1.0)
                            * (tonumber(Config.SpeedUsageMultiplier) or 0.35)

                        delta = baseUsagePerSecond
                            * rpm
                            * speedMultiplier
                            * classMultiplier
                            * (waitMs / 1000.0)
                    end

                    local nextFuelLevel = setVehicleFuelLevelSafe(vehicle, fuelLevel - delta, true)
                    if isFuelExhausted(nextFuelLevel) then
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
        if refuelProgressState.visible == true and not IsPauseMenuActive() then
            drawRefuelProgress()
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

    hideRefuelProgress()
    stopRefuelAnimation(PlayerPedId())
    refuelInProgress = false
    pendingRefuelRequests = {}
    modelTankCapacityCache = {}
    refuelProgressState = {
        visible = false,
        label = '',
        progress = 0.0,
        totalCost = 0,
        liters = 0.0
    }
end)

exports('getFuel', function(vehicle)
    return getVehicleFuelLevelSafe(vehicle)
end)

exports('getTankCapacity', function(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) or not isFuelManagedVehicle(vehicle) then
        return nil
    end

    return getVehicleTankCapacity(vehicle)
end)

exports('getEmptyFuelThreshold', function()
    return tonumber(Config.EmptyFuelThreshold) or 0.1
end)

exports('isOutOfFuel', function(vehicle)
    local fuelLevel = getVehicleFuelLevelSafe(vehicle)
    if fuelLevel == nil then
        return nil
    end

    return fuelLevel <= (tonumber(Config.EmptyFuelThreshold) or 0.1)
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