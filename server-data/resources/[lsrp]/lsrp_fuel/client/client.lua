local refuelInProgress = false
local modelTankCapacityCache = {}
local electricVehicleModelCache = {}
local activeChargeLockedVehicle = 0
local EV_CHARGE_LOCK_STATE_BAG_KEY = 'lsrpChargeLocked'
local refuelProgressState = {
    visible = false,
    label = '',
    progress = 0.0,
    totalCost = 0,
    liters = 0.0,
    serviceMode = 'refuel',
    displayPercent = 0.0
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

local function normalizeLookupString(value)
    local trimmed = trimString(value)
    if not trimmed then
        return nil
    end

    return trimmed:lower()
end

local function rotationToDirection(rotation)
    local adjustedX = math.rad(tonumber(rotation and rotation.x) or 0.0)
    local adjustedZ = math.rad(tonumber(rotation and rotation.z) or 0.0)
    local cosX = math.abs(math.cos(adjustedX))

    return vector3(
        -math.sin(adjustedZ) * cosX,
        math.cos(adjustedZ) * cosX,
        math.sin(adjustedX)
    )
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

local function isVehicleChargeLocked(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return false
    end

    local entityState = Entity(vehicle).state
    return entityState and entityState[EV_CHARGE_LOCK_STATE_BAG_KEY] == true or false
end

local function setVehicleChargeLockState(vehicle, locked, replicate)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return false
    end

    local entityState = Entity(vehicle).state
    if not entityState then
        return false
    end

    local normalizedLocked = locked == true
    if entityState[EV_CHARGE_LOCK_STATE_BAG_KEY] ~= normalizedLocked then
        entityState:set(EV_CHARGE_LOCK_STATE_BAG_KEY, normalizedLocked, replicate == true)
    end

    if normalizedLocked then
        activeChargeLockedVehicle = vehicle
    elseif activeChargeLockedVehicle == vehicle then
        activeChargeLockedVehicle = 0
    end

    return true
end

local function applyVehicleChargeLock(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return
    end

    requestVehicleControl(vehicle, 100)
    SetVehicleEngineOn(vehicle, false, true, true)
    SetVehicleUndriveable(vehicle, true)
    SetVehicleHandbrake(vehicle, true)
    BringVehicleToHalt(vehicle, 0.1, 1, false)

    if math.abs(GetEntitySpeed(vehicle)) > 0.05 then
        SetVehicleForwardSpeed(vehicle, 0.0)
    end
end

local function releaseVehicleChargeLock(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return
    end

    requestVehicleControl(vehicle, 100)
    SetVehicleUndriveable(vehicle, false)
    SetVehicleHandbrake(vehicle, false)
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
    if GetResourceState('lsrp_framework') == 'started' then
        exports['lsrp_framework']:notify(tostring(message or ''), 'info')
        return
    end

    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(tostring(message or ''))
    EndTextCommandThefeedPostTicker(false, false)
end

local function triggerFrameworkCallback(callbackName, payload, timeoutMs)
    if GetResourceState('lsrp_framework') ~= 'started' then
        return {
            ok = false,
            error = 'Fuel service is unavailable right now.'
        }
    end

    local ok, response = pcall(function()
        return exports['lsrp_framework']:triggerServerCallback(callbackName, payload, timeoutMs)
    end)

    if not ok or type(response) ~= 'table' then
        return {
            ok = false,
            error = 'Fuel service is unavailable right now.'
        }
    end

    return response
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

local function clampPercent(value)
    return math.max(0.0, math.min(100.0, tonumber(value) or 0.0))
end

local function getEVChargeCurveConfig()
    local fullRefuelDurationMs = math.max(1, math.floor(tonumber(Config.FullRefuelDurationMs) or 60000))
    local fullChargeDurationMs = math.max(fullRefuelDurationMs, math.floor(fullRefuelDurationMs * math.max(1.0, tonumber(Config.FullEVChargeDurationMultiplier) or 3.0)))
    local minChargeDurationMs = math.max(1, math.floor(tonumber(Config.MinEVChargeDurationMs) or tonumber(Config.MinRefuelDurationMs) or 1500))
    local thresholdPercent = clampPercent(tonumber(Config.EVChargeFastThresholdPercent) or 80.0)
    local fastPhaseTimeShare = math.max(0.05, math.min(0.95, tonumber(Config.EVChargeFastPhaseTimeShare) or 0.6))

    thresholdPercent = math.max(1.0, math.min(99.0, thresholdPercent))

    return {
        fullChargeDurationMs = fullChargeDurationMs,
        minChargeDurationMs = minChargeDurationMs,
        thresholdPercent = thresholdPercent,
        fastPhaseTimeShare = fastPhaseTimeShare
    }
end

local function calculateEVChargeSegmentDurationMs(segmentStartPercent, segmentEndPercent, curveConfig)
    local startPercent = clampPercent(segmentStartPercent)
    local endPercent = clampPercent(segmentEndPercent)
    if endPercent <= startPercent then
        return 0.0
    end

    local thresholdPercent = curveConfig.thresholdPercent
    local fullChargeDurationMs = curveConfig.fullChargeDurationMs
    local fastPhaseTimeShare = curveConfig.fastPhaseTimeShare

    if endPercent <= thresholdPercent then
        return fullChargeDurationMs
            * fastPhaseTimeShare
            * ((endPercent - startPercent) / math.max(1.0, thresholdPercent))
    end

    return fullChargeDurationMs
        * (1.0 - fastPhaseTimeShare)
        * ((endPercent - startPercent) / math.max(1.0, 100.0 - thresholdPercent))
end

local function createEVChargeProfile(currentFuel, targetFuel, tankCapacity)
    local startPercent = getFuelPercent(currentFuel, tankCapacity)
    local targetPercent = getFuelPercent(targetFuel, tankCapacity)
    local curveConfig = getEVChargeCurveConfig()
    local thresholdPercent = curveConfig.thresholdPercent
    local fastEndPercent = math.min(targetPercent, thresholdPercent)
    local slowStartPercent = math.max(startPercent, thresholdPercent)
    local rawFastDurationMs = 0.0
    local rawSlowDurationMs = 0.0

    if startPercent < fastEndPercent then
        rawFastDurationMs = calculateEVChargeSegmentDurationMs(startPercent, fastEndPercent, curveConfig)
    end

    if slowStartPercent < targetPercent then
        rawSlowDurationMs = calculateEVChargeSegmentDurationMs(slowStartPercent, targetPercent, curveConfig)
    end

    local rawDurationMs = rawFastDurationMs + rawSlowDurationMs
    local durationMs = math.max(curveConfig.minChargeDurationMs, math.floor(rawDurationMs + 0.5))
    local scale = rawDurationMs > 0.0 and (durationMs / rawDurationMs) or 1.0

    return {
        startPercent = startPercent,
        targetPercent = targetPercent,
        fastEndPercent = fastEndPercent,
        durationMs = durationMs,
        fastDurationMs = rawFastDurationMs * scale,
        slowDurationMs = rawSlowDurationMs * scale
    }
end

local function getEVChargePercentAtElapsed(profile, elapsedMs)
    if type(profile) ~= 'table' then
        return 0.0
    end

    local clampedElapsedMs = math.max(0.0, math.min(tonumber(elapsedMs) or 0.0, tonumber(profile.durationMs) or 0.0))
    local startPercent = clampPercent(profile.startPercent)
    local targetPercent = clampPercent(profile.targetPercent)
    local fastEndPercent = clampPercent(profile.fastEndPercent)
    local fastDurationMs = math.max(0.0, tonumber(profile.fastDurationMs) or 0.0)
    local slowDurationMs = math.max(0.0, tonumber(profile.slowDurationMs) or 0.0)

    if clampedElapsedMs <= 0.0 then
        return startPercent
    end

    if clampedElapsedMs >= math.max(1.0, tonumber(profile.durationMs) or 0.0) then
        return targetPercent
    end

    if fastDurationMs > 0.0 and startPercent < fastEndPercent then
        if clampedElapsedMs <= fastDurationMs then
            local phaseProgress = clampedElapsedMs / fastDurationMs
            return startPercent + ((fastEndPercent - startPercent) * phaseProgress)
        end

        clampedElapsedMs = clampedElapsedMs - fastDurationMs
    end

    if slowDurationMs > 0.0 and fastEndPercent < targetPercent then
        local phaseProgress = math.max(0.0, math.min(1.0, clampedElapsedMs / slowDurationMs))
        return fastEndPercent + ((targetPercent - fastEndPercent) * phaseProgress)
    end

    return targetPercent
end

local function isModelConfiguredElectric(modelHash)
    if not modelHash or modelHash == 0 then
        return false
    end

    for _, configuredModelHash in ipairs(Config.ElectricVehicleModels or {}) do
        if configuredModelHash == modelHash then
            return true
        end
    end

    return false
end

local function isVehicleElectric(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return false
    end

    local modelHash = GetEntityModel(vehicle)
    if modelHash and modelHash ~= 0 and electricVehicleModelCache[modelHash] ~= nil then
        return electricVehicleModelCache[modelHash] == true
    end

    local isElectric = false
    if Config.UseNativeElectricVehicleDetection ~= false and type(GetIsVehicleElectric) == 'function' then
        local ok, result = pcall(GetIsVehicleElectric, vehicle)
        if ok and result == true then
            isElectric = true
        end
    end

    if not isElectric then
        isElectric = isModelConfiguredElectric(modelHash)
    end

    if modelHash and modelHash ~= 0 then
        electricVehicleModelCache[modelHash] = isElectric == true
    end

    return isElectric
end

local function getServiceModeForVehicle(vehicle)
    if isVehicleElectric(vehicle) then
        return 'charge'
    end

    return 'refuel'
end

local function getServicePresentParticiple(serviceMode)
    if serviceMode == 'charge' then
        return 'Charging'
    end

    return 'Refueling'
end

local function getRequiredStationLabel(serviceMode)
    if serviceMode == 'charge' then
        return 'EV charging station'
    end

    return 'pump'
end

local function getEntityArchetypeNameSafe(entity)
    if entity == 0 or not DoesEntityExist(entity) or type(GetEntityArchetypeName) ~= 'function' then
        return nil
    end

    local ok, archetypeName = pcall(GetEntityArchetypeName, entity)
    if not ok then
        return nil
    end

    return trimString(archetypeName)
end

local function formatModelHash(modelHash)
    local numericHash = tonumber(modelHash)
    if not numericHash then
        return 'nil'
    end

    if numericHash < 0 then
        numericHash = numericHash + 4294967296
    end

    numericHash = math.floor(numericHash)
    return ('%u (0x%08X)'):format(numericHash, numericHash)
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

local function setRefuelProgressVisible(visible, label, progress, totalCost, liters, serviceMode, displayPercent)
    refuelProgressState.visible = visible == true
    refuelProgressState.label = tostring(label or '')
    refuelProgressState.progress = math.max(0.0, math.min(1.0, tonumber(progress) or 0.0))
    refuelProgressState.totalCost = math.max(0, math.floor(tonumber(totalCost) or 0))
    refuelProgressState.liters = math.max(0.0, tonumber(liters) or 0.0)
    refuelProgressState.serviceMode = serviceMode == 'charge' and 'charge' or 'refuel'
    refuelProgressState.displayPercent = clampPercent(displayPercent)
end

local function hideRefuelProgress()
    setRefuelProgressVisible(false, '', 0.0, 0, 0.0, 'refuel', 0.0)
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
    local detailText = ('%d%%  |  %.1fL  |  %s'):format(math.floor((progress * 100.0) + 0.5), refuelProgressState.liters, formatCurrency(refuelProgressState.totalCost))

    if refuelProgressState.serviceMode == 'charge' then
        detailText = ('%d%%  |  %s'):format(math.floor(refuelProgressState.displayPercent + 0.5), formatCurrency(refuelProgressState.totalCost))
    end

    drawFuelHudRect(cardX, cardY, cardWidth, cardHeight, 9, 16, 24, 205)
    drawFuelHudText(cardX, cardY - 0.018, refuelProgressState.label ~= '' and refuelProgressState.label or 'Refueling vehicle', 0.31, 244, 241, 236, 225, true)
    drawFuelHudText(cardX, cardY - 0.001, detailText, 0.24, 214, 221, 228, 215, true)
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

local function disableChargeDriveControls()
    DisableControlAction(0, 59, true)
    DisableControlAction(0, 60, true)
    DisableControlAction(0, 71, true)
    DisableControlAction(0, 72, true)
    DisableControlAction(0, 76, true)
end

local function ensurePedReadyForRefuel(ped, vehicle, serviceMode)
    if ped == 0 or not DoesEntityExist(ped) then
        return false
    end

    serviceMode = serviceMode == 'charge' and 'charge' or 'refuel'

    if IsPedInAnyVehicle(ped, false) then
        if vehicle == 0 or not DoesEntityExist(vehicle) or GetVehiclePedIsIn(ped, false) ~= vehicle or GetPedInVehicleSeat(vehicle, -1) ~= ped then
            return false
        end

        if serviceMode == 'charge' then
            return true
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

local function leaveVehicleForCharging(ped, vehicle)
    if ped == 0 or not DoesEntityExist(ped) or vehicle == 0 or not DoesEntityExist(vehicle) then
        return false
    end

    if not IsPedInAnyVehicle(ped, false) or GetVehiclePedIsIn(ped, false) ~= vehicle then
        return true
    end

    TaskLeaveVehicle(ped, vehicle, 0)

    local timeoutAt = GetGameTimer() + 4000
    while IsPedInAnyVehicle(ped, false) and GetGameTimer() < timeoutAt do
        DisableControlAction(0, 75, true)
        Wait(0)
    end

    return not IsPedInAnyVehicle(ped, false)
end

local function quoteRefuelCost(units)
    local normalizedUnits = tonumber(units)
    if not normalizedUnits or normalizedUnits <= 0 then
        return nil
    end

    return math.max(1, math.ceil(normalizedUnits * (tonumber(Config.RefuelCostPerUnit) or 1)))
end

local function getNearestWorldObjectInteraction(playerCoords, modelHashes, scanRadius, interactDistance)
    local nearestObject = nil
    local nearestDistance = interactDistance + 0.001

    for _, modelHash in ipairs(modelHashes or {}) do
        local worldObject = GetClosestObjectOfType(playerCoords.x, playerCoords.y, playerCoords.z, scanRadius, modelHash, false, false, false)
        if worldObject ~= 0 and DoesEntityExist(worldObject) then
            local objectCoords = GetEntityCoords(worldObject)
            local distance = #(playerCoords - objectCoords)

            if distance <= interactDistance and distance < nearestDistance then
                nearestDistance = distance
                nearestObject = {
                    entity = worldObject,
                    coords = objectCoords,
                    distance = distance
                }
            end
        end
    end

    return nearestObject
end

local function getNearestConfiguredStationInteraction(playerCoords, stations, interactDistance)
    local nearestStation = nil
    local nearestDistance = (tonumber(interactDistance) or 0.0) + 0.001

    for _, station in ipairs(stations or {}) do
        local stationCoords = nil
        local stationLabel = nil

        if type(station) == 'vector3' then
            stationCoords = station
        elseif type(station) == 'table' then
            stationCoords = station.coords
            stationLabel = trimString(station.label)
        end

        if stationCoords then
            local distance = #(playerCoords - stationCoords)
            if distance <= interactDistance and distance < nearestDistance then
                nearestDistance = distance
                nearestStation = {
                    entity = 0,
                    coords = stationCoords,
                    distance = distance,
                    label = stationLabel
                }
            end
        end
    end

    return nearestStation
end

local function getCloserInteraction(primaryInteraction, secondaryInteraction)
    if primaryInteraction and secondaryInteraction then
        if (tonumber(secondaryInteraction.distance) or 999999.0) < (tonumber(primaryInteraction.distance) or 999999.0) then
            return secondaryInteraction
        end

        return primaryInteraction
    end

    return primaryInteraction or secondaryInteraction
end

local function getNearestFuelPumpInteraction(playerCoords)
    return getNearestWorldObjectInteraction(
        playerCoords,
        Config.PumpModels,
        tonumber(Config.PumpScanRadius or Config.PumpSearchRadius) or 5.0,
        tonumber(Config.PumpInteractDistance or Config.PumpSearchRadius) or 1.8
    )
end

local function getEVChargerVehicleDistance(interaction)
    if interaction and tonumber(interaction.vehicleDistanceOverride) then
        return tonumber(interaction.vehicleDistanceOverride) or 0.0
    end

    return tonumber(Config.EVChargerVehicleDistance) or tonumber(Config.PumpVehicleDistance) or tonumber(Config.VehicleSearchRadius) or 4.0
end

local function getNearestEVChargerInteraction(playerCoords)
    local configuredLocationInteraction = getNearestConfiguredStationInteraction(
        playerCoords,
        Config.EVChargerLocations,
        tonumber(Config.EVChargerLocationInteractDistance or Config.PumpInteractDistance or Config.EVChargerInteractDistance) or 2.75
    )

    if configuredLocationInteraction then
        configuredLocationInteraction.vehicleDistanceOverride = tonumber(Config.EVChargerLocationVehicleDistance or Config.PumpVehicleDistance or Config.EVChargerVehicleDistance) or 6.0
        return configuredLocationInteraction
    end

    return nil
end

local function collectNearbyObjectDebug(radius)
    local playerPed = PlayerPedId()
    if playerPed == 0 or not DoesEntityExist(playerPed) then
        return {}
    end

    local playerCoords = GetEntityCoords(playerPed)
    local maxDistance = tonumber(radius) or 10.0
    local nearbyObjects = {}

    for _, worldObject in ipairs(GetGamePool('CObject')) do
        if worldObject ~= 0 and DoesEntityExist(worldObject) then
            local objectCoords = GetEntityCoords(worldObject)
            local distance = #(playerCoords - objectCoords)

            if distance <= maxDistance then
                nearbyObjects[#nearbyObjects + 1] = {
                    entity = worldObject,
                    distance = distance,
                    modelHash = GetEntityModel(worldObject),
                    archetypeName = getEntityArchetypeNameSafe(worldObject),
                    coords = objectCoords
                }
            end
        end
    end

    table.sort(nearbyObjects, function(left, right)
        return (left.distance or 999999.0) < (right.distance or 999999.0)
    end)

    return nearbyObjects
end

local function getLookTargetDebug(maxDistance)
    local playerPed = PlayerPedId()
    if playerPed == 0 or not DoesEntityExist(playerPed) then
        return nil
    end

    local cameraCoords = GetGameplayCamCoord()
    local direction = rotationToDirection(GetGameplayCamRot(2))
    local distance = tonumber(maxDistance) or 20.0
    local destination = cameraCoords + (direction * distance)
    local rayHandle = StartShapeTestLosProbe(
        cameraCoords.x,
        cameraCoords.y,
        cameraCoords.z,
        destination.x,
        destination.y,
        destination.z,
        16,
        playerPed,
        7
    )

    local _, hit, endCoords, _, entityHit = GetShapeTestResult(rayHandle)
    if hit ~= 1 or entityHit == 0 or not DoesEntityExist(entityHit) then
        return nil
    end

    return {
        entity = entityHit,
        entityType = GetEntityType(entityHit),
        modelHash = GetEntityModel(entityHit),
        archetypeName = getEntityArchetypeNameSafe(entityHit),
        coords = GetEntityCoords(entityHit),
        hitCoords = endCoords
    }
end

local function getClosestFuelVehicle(originCoords, maxDistance, expectElectric)
    local closestVehicle = 0
    local closestDistance = (tonumber(maxDistance) or tonumber(Config.VehicleSearchRadius) or 4.0) + 0.001

    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) and isFuelManagedVehicle(vehicle) then
            if expectElectric == nil or isVehicleElectric(vehicle) == expectElectric then
                local vehicleCoords = GetEntityCoords(vehicle)
                local distance = #(originCoords - vehicleCoords)

                if distance <= closestDistance then
                    closestDistance = distance
                    closestVehicle = vehicle
                end
            end
        end
    end

    return closestVehicle, closestDistance
end

local function beginRefuel(vehicle, purchasedFuelUnits, totalCost, serviceMode)
    if refuelInProgress then
        return
    end

    serviceMode = serviceMode == 'charge' and 'charge' or 'refuel'

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        notify(('%s failed: vehicle is no longer available.'):format(getServicePresentParticiple(serviceMode)))
        return
    end

    local currentFuel = getVehicleFuelLevelSafe(vehicle)
    if currentFuel == nil then
        notify(('%s failed: vehicle fuel data is unavailable.'):format(getServicePresentParticiple(serviceMode)))
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
    local evChargeProfile = nil
    local durationMs = math.max(
        math.floor(tonumber(Config.MinRefuelDurationMs) or 1500),
        math.floor((tonumber(Config.FullRefuelDurationMs) or 60000) * fillFraction)
    )

    if serviceMode == 'charge' then
        evChargeProfile = createEVChargeProfile(currentFuel, targetFuel, tankCapacity)
        durationMs = math.max(1, math.floor(evChargeProfile.durationMs or durationMs))
    end

    local vehicleName = getVehicleDisplayName(vehicle)

    refuelInProgress = true
    hideRefuelProgress()

    CreateThread(function()
        local ped = PlayerPedId()
        if not ensurePedReadyForRefuel(ped, vehicle, serviceMode) then
            refuelInProgress = false
            if serviceMode == 'charge' then
                notify('Sit in the driver seat or stand next to the vehicle to start charging.')
            else
                notify('Exit the vehicle to start refueling.')
            end
            return
        end

        if not DoesEntityExist(vehicle) then
            refuelInProgress = false
            notify(('%s failed: vehicle is no longer available.'):format(getServicePresentParticiple(serviceMode)))
            return
        end

        local chargeLockApplied = false
        if serviceMode == 'charge' then
            chargeLockApplied = setVehicleChargeLockState(vehicle, true, true)
            applyVehicleChargeLock(vehicle)
        end

        SetVehicleEngineOn(vehicle, false, true, true)
        if serviceMode ~= 'charge' then
            startRefuelAnimation(ped, vehicle)
        else
            ClearPedTasks(ped)

            if GetPedInVehicleSeat(vehicle, -1) == ped and not leaveVehicleForCharging(ped, vehicle) then
                if chargeLockApplied then
                    setVehicleChargeLockState(vehicle, false, true)
                    releaseVehicleChargeLock(vehicle)
                end
                refuelInProgress = false
                notify('Exit the vehicle to keep charging.')
                return
            end
        end

        local endAt = GetGameTimer() + durationMs

        while GetGameTimer() < endAt do
            if not DoesEntityExist(vehicle) then
                break
            end

            if serviceMode ~= 'charge' then
                disableRefuelControls()
            else
                applyVehicleChargeLock(vehicle)
            end

            if serviceMode ~= 'charge'
                and not IsEntityPlayingAnim(ped, trimString(Config and Config.RefuelAnimationDict) or '', trimString(Config and Config.RefuelAnimationName) or '', 3)
                and not IsPedActiveInScenario(ped)
            then
                startRefuelAnimation(ped, vehicle)
            end

            local remainingMs = math.max(0, endAt - GetGameTimer())
            local elapsedMs = math.max(0, durationMs - remainingMs)
            local progress = 1.0 - (remainingMs / math.max(1, durationMs))
            local currentRefuelFuel = currentFuel + (litersAdded * progress)
            local displayProgress = progress
            local displayPercent = progress * 100.0

            if serviceMode == 'charge' and evChargeProfile then
                displayPercent = getEVChargePercentAtElapsed(evChargeProfile, elapsedMs)
                displayProgress = displayPercent / 100.0
                currentRefuelFuel = tankCapacity * (displayPercent / 100.0)
            end

            setVehicleFuelLevelSafe(vehicle, currentRefuelFuel, true)
            setRefuelProgressVisible(true, ('%s %s'):format(getServicePresentParticiple(serviceMode), vehicleName), displayProgress, totalCost, litersAdded, serviceMode, displayPercent)
            showHelpPrompt(('%s %s...'):format(getServicePresentParticiple(serviceMode), vehicleName))
            Wait(0)
        end

        if serviceMode ~= 'charge' then
            stopRefuelAnimation(ped)
        end
        hideRefuelProgress()

        if chargeLockApplied and DoesEntityExist(vehicle) then
            setVehicleChargeLockState(vehicle, false, true)
            releaseVehicleChargeLock(vehicle)
        end

        if DoesEntityExist(vehicle) then
            setVehicleFuelLevelSafe(vehicle, targetFuel, true)
            notify(('%s %s for %s.'):format(serviceMode == 'charge' and 'Charged' or 'Refueled', vehicleName, formatCurrency(totalCost)))
        else
            notify(('%s completed, but the vehicle is no longer nearby.'):format(getServicePresentParticiple(serviceMode)))
        end

        refuelInProgress = false
    end)
end

CreateThread(function()
    while true do
        local waitMs = 500
        local localPed = PlayerPedId()

        for _, vehicle in ipairs(GetGamePool('CVehicle')) do
            if vehicle ~= 0 and DoesEntityExist(vehicle) and isVehicleChargeLocked(vehicle) then
                waitMs = 0
                applyVehicleChargeLock(vehicle)

                if localPed ~= 0 and DoesEntityExist(localPed) and GetPedInVehicleSeat(vehicle, -1) == localPed then
                    disableChargeDriveControls()
                end
            end
        end

        Wait(waitMs)
    end
end)

local function requestRefuel(vehicle, serviceMode)
    if refuelInProgress or vehicle == 0 or not DoesEntityExist(vehicle) then
        return
    end

    serviceMode = serviceMode == 'charge' and 'charge' or 'refuel'

    local fuelNeeded = getFuelNeeded(vehicle)
    if fuelNeeded <= (tonumber(Config.EmptyFuelThreshold) or 0.1) then
        notify(('The %s tank is already full.'):format(getVehicleDisplayName(vehicle)))
        return
    end

    CreateThread(function()
        local response = triggerFrameworkCallback('lsrp_fuel:requestRefuel', {
            fuelUnits = fuelNeeded
        }, 5000)

        if response.ok ~= true or type(response.data) ~= 'table' then
            notify(response.error or 'Fuel purchase was declined.')
            return
        end

        beginRefuel(vehicle, response.data.units, response.data.cost, serviceMode)
    end)
end

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
                local seatedVehicle = 0
                local pumpInteraction = getNearestFuelPumpInteraction(playerCoords)
                local evChargerInteraction = getNearestEVChargerInteraction(playerCoords)

                if IsPedInAnyVehicle(ped, false) then
                    seatedVehicle = GetVehiclePedIsIn(ped, false)
                end

                if seatedVehicle ~= 0 and DoesEntityExist(seatedVehicle) and GetPedInVehicleSeat(seatedVehicle, -1) == ped then
                    local vehicleCoords = GetEntityCoords(seatedVehicle)
                    pumpInteraction = getCloserInteraction(pumpInteraction, getNearestFuelPumpInteraction(vehicleCoords))
                    evChargerInteraction = getCloserInteraction(evChargerInteraction, getNearestEVChargerInteraction(vehicleCoords))
                end

                if pumpInteraction or evChargerInteraction then
                    waitMs = 0

                    local vehicle = 0
                    local serviceMode = nil
                    local interaction = nil

                    if seatedVehicle ~= 0
                        and DoesEntityExist(seatedVehicle)
                        and isFuelManagedVehicle(seatedVehicle)
                        and GetPedInVehicleSeat(seatedVehicle, -1) == ped
                    then
                        serviceMode = getServiceModeForVehicle(seatedVehicle)
                        interaction = serviceMode == 'charge' and evChargerInteraction or pumpInteraction

                        if interaction then
                            local seatedVehicleCoords = GetEntityCoords(seatedVehicle)
                            local seatedDistance = #(seatedVehicleCoords - interaction.coords)
                            local maxVehicleDistance = serviceMode == 'charge'
                                and getEVChargerVehicleDistance(interaction)
                                or (tonumber(Config.PumpVehicleDistance) or tonumber(Config.VehicleSearchRadius) or 4.0)

                            if seatedDistance <= maxVehicleDistance then
                                vehicle = seatedVehicle
                            end
                        elseif serviceMode == 'charge' and pumpInteraction then
                            showHelpPrompt(('The %s must be charged at an EV charging station.'):format(getVehicleDisplayName(seatedVehicle)))
                        elseif serviceMode == 'refuel' and evChargerInteraction then
                            showHelpPrompt(('The %s cannot use EV charging stations.'):format(getVehicleDisplayName(seatedVehicle)))
                        end
                    end

                    if vehicle == 0 then
                        local bestCandidate = nil

                        if pumpInteraction then
                            local pumpVehicle = getClosestFuelVehicle(
                                pumpInteraction.coords,
                                tonumber(Config.PumpVehicleDistance) or tonumber(Config.VehicleSearchRadius) or 4.0,
                                false
                            )

                            if pumpVehicle ~= 0 then
                                bestCandidate = {
                                    interaction = pumpInteraction,
                                    vehicle = pumpVehicle,
                                    distance = pumpInteraction.distance,
                                    serviceMode = 'refuel'
                                }
                            end
                        end

                        if evChargerInteraction then
                            local chargerVehicle = getClosestFuelVehicle(
                                evChargerInteraction.coords,
                                getEVChargerVehicleDistance(evChargerInteraction),
                                true
                            )

                            if chargerVehicle ~= 0 and (bestCandidate == nil or evChargerInteraction.distance < bestCandidate.distance) then
                                bestCandidate = {
                                    interaction = evChargerInteraction,
                                    vehicle = chargerVehicle,
                                    distance = evChargerInteraction.distance,
                                    serviceMode = 'charge'
                                }
                            end
                        end

                        if bestCandidate then
                            interaction = bestCandidate.interaction
                            vehicle = bestCandidate.vehicle
                            serviceMode = bestCandidate.serviceMode
                        end
                    end

                    if vehicle ~= 0 and serviceMode == nil then
                        serviceMode = getServiceModeForVehicle(vehicle)
                    end

                    if vehicle ~= 0 and interaction == nil then
                        interaction = serviceMode == 'charge' and evChargerInteraction or pumpInteraction
                    end

                    if vehicle == 0 or not DoesEntityExist(vehicle) then
                        if evChargerInteraction and not pumpInteraction then
                            showHelpPrompt('Bring an electric vehicle next to the charger to charge.')
                        else
                            showHelpPrompt('Bring a vehicle next to the pump to refuel.')
                        end
                    else
                        local vehicleName = getVehicleDisplayName(vehicle)
                        local driver = GetPedInVehicleSeat(vehicle, -1)
                        local fuelNeeded = getFuelNeeded(vehicle)
                        local playerIsDriver = driver == ped
                        local stationLabel = getRequiredStationLabel(serviceMode)
                        local actionLabel = serviceMode == 'charge' and 'charge' or 'refuel'

                        if fuelNeeded <= (tonumber(Config.EmptyFuelThreshold) or 0.1) then
                            showHelpPrompt(('The %s tank is already full.'):format(vehicleName))
                        elseif driver ~= 0 and not playerIsDriver then
                            showHelpPrompt(('The %s must be unoccupied to %s.'):format(vehicleName, actionLabel))
                        elseif GetIsVehicleEngineRunning(vehicle) then
                            showHelpPrompt(('Turn the %s engine off before %s.'):format(vehicleName, serviceMode == 'charge' and 'charging' or 'refueling'))
                        elseif interaction == nil then
                            showHelpPrompt(('Move the %s next to an %s to %s.'):format(vehicleName, stationLabel, actionLabel))
                        else
                            local totalCost = quoteRefuelCost(fuelNeeded)
                            showHelpPrompt(('Press ~INPUT_CONTEXT~ to %s %s for %s.'):format(actionLabel, vehicleName, formatCurrency(totalCost or 0)))

                            if IsControlJustPressed(0, tonumber(Config.RefuelControl) or 38) then
                                requestRefuel(vehicle, serviceMode)
                            end
                        end
                    end
                end
            end
        end

        Wait(waitMs)
    end
end)

if type(AddStateBagChangeHandler) == 'function' and type(GetEntityFromStateBagName) == 'function' then
    AddStateBagChangeHandler(EV_CHARGE_LOCK_STATE_BAG_KEY, nil, function(bagName, _, value)
        local entity = GetEntityFromStateBagName(bagName)
        if entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then
            return
        end

        if value == true then
            applyVehicleChargeLock(entity)
            return
        end

        releaseVehicleChargeLock(entity)
    end)
end

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
    if activeChargeLockedVehicle ~= 0 and DoesEntityExist(activeChargeLockedVehicle) then
        setVehicleChargeLockState(activeChargeLockedVehicle, false, true)
        releaseVehicleChargeLock(activeChargeLockedVehicle)
    end
    refuelInProgress = false
    activeChargeLockedVehicle = 0
    modelTankCapacityCache = {}
    electricVehicleModelCache = {}
    refuelProgressState = {
        visible = false,
        label = '',
        progress = 0.0,
        totalCost = 0,
        liters = 0.0
    }
end)

RegisterCommand('fueldebugcharger', function()
    local lines = {}
    local playerPed = PlayerPedId()
    if playerPed == 0 or not DoesEntityExist(playerPed) then
        notify('Player ped is unavailable for charger debug.')
        return
    end

    local playerCoords = GetEntityCoords(playerPed)
    local lookedAtTarget = getLookTargetDebug(30.0)
    local configuredMatch = getNearestEVChargerInteraction(playerCoords)
    local nearbyObjects = collectNearbyObjectDebug(20.0)

    lines[#lines + 1] = ('Configured charger match: %s'):format(configuredMatch and 'yes' or 'no')
    if configuredMatch then
        lines[#lines + 1] = ('configured dist=%.2f hash=%s archetype=%s coords=(%.2f, %.2f, %.2f)'):format(
            tonumber(configuredMatch.distance) or 0.0,
            formatModelHash(configuredMatch.modelHash),
            tostring(configuredMatch.archetypeName or 'unknown'),
            tonumber(configuredMatch.coords and configuredMatch.coords.x) or 0.0,
            tonumber(configuredMatch.coords and configuredMatch.coords.y) or 0.0,
            tonumber(configuredMatch.coords and configuredMatch.coords.z) or 0.0
        )
    end

    if lookedAtTarget then
        lines[#lines + 1] = ('look type=%s hash=%s archetype=%s coords=(%.2f, %.2f, %.2f) hit=(%.2f, %.2f, %.2f)'):format(
            tostring(lookedAtTarget.entityType or 'nil'),
            formatModelHash(lookedAtTarget.modelHash),
            tostring(lookedAtTarget.archetypeName or 'unknown'),
            tonumber(lookedAtTarget.coords and lookedAtTarget.coords.x) or 0.0,
            tonumber(lookedAtTarget.coords and lookedAtTarget.coords.y) or 0.0,
            tonumber(lookedAtTarget.coords and lookedAtTarget.coords.z) or 0.0,
            tonumber(lookedAtTarget.hitCoords and lookedAtTarget.hitCoords.x) or 0.0,
            tonumber(lookedAtTarget.hitCoords and lookedAtTarget.hitCoords.y) or 0.0,
            tonumber(lookedAtTarget.hitCoords and lookedAtTarget.hitCoords.z) or 0.0
        )
    else
        lines[#lines + 1] = 'look target: none'
    end

    if #nearbyObjects == 0 then
        lines[#lines + 1] = 'No nearby objects found within 20.0 units.'
    else
        local maxResults = math.min(15, #nearbyObjects)

        for index = 1, maxResults do
            local entry = nearbyObjects[index]
            lines[#lines + 1] = ('[%d] dist=%.2f hash=%s archetype=%s coords=(%.2f, %.2f, %.2f)%s'):format(
                index,
                tonumber(entry.distance) or 0.0,
                formatModelHash(entry.modelHash),
                tostring(entry.archetypeName or 'unknown'),
                tonumber(entry.coords and entry.coords.x) or 0.0,
                tonumber(entry.coords and entry.coords.y) or 0.0,
                tonumber(entry.coords and entry.coords.z) or 0.0,
                ''
            )
        end
    end

    print('[lsrp_fuel] Nearby charger debug objects:\n' .. table.concat(lines, '\n'))
    if lookedAtTarget then
        notify(('Charger debug logged. Look target archetype: %s'):format(tostring(lookedAtTarget.archetypeName or formatModelHash(lookedAtTarget.modelHash))))
    else
        notify('Charger debug logged to F8/console with look target and nearby object details.')
    end
end, false)

RegisterCommand('fueldebuglook', function()
    local target = getLookTargetDebug(25.0)
    if not target then
        notify('No entity detected in front of the camera.')
        return
    end

    print(('[lsrp_fuel] Look target debug: type=%s hash=%s archetype=%s coords=(%.2f, %.2f, %.2f) hit=(%.2f, %.2f, %.2f)')
        :format(
            tostring(target.entityType or 'nil'),
            tostring(target.modelHash or 'nil'),
            tostring(target.archetypeName or 'unknown'),
            tonumber(target.coords and target.coords.x) or 0.0,
            tonumber(target.coords and target.coords.y) or 0.0,
            tonumber(target.coords and target.coords.z) or 0.0,
            tonumber(target.hitCoords and target.hitCoords.x) or 0.0,
            tonumber(target.hitCoords and target.hitCoords.y) or 0.0,
            tonumber(target.hitCoords and target.hitCoords.z) or 0.0
        ))
    notify('Logged looked-at entity to F8/console for charger debug.')
end, false)

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