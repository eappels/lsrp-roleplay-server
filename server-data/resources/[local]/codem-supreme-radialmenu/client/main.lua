local isMenuOpen = false
local DynamicMenuItems = {}
local FinalMenuItems = {}
local currentMugshot = nil
local radialBehaviour = 'press' -- 'press' or 'hold'
CodemDevAccess = CodemDevAccess or {
    loaded = false,
    isAuthorized = false,
    denialMessage = 'Dev admin rights are required.',
    lastRefreshAt = 0
}
local pendingOpenAfterPermission = false

local function notifyPlayer(message)
    if type(message) ~= 'string' or message == '' then
        return
    end

    if GetResourceState('lsrp_framework') == 'started' then
        local ok = pcall(function()
            exports['lsrp_framework']:notify({
                title = 'Dev Menu',
                description = message,
                type = 'inform'
            })
        end)

        if ok then
            return
        end
    end

    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end

local function promptTextInput(title, defaultText, maxLength)
    AddTextEntry('FMMC_KEY_TIP1', title)
    DisplayOnscreenKeyboard(1, 'FMMC_KEY_TIP1', '', defaultText or '', '', '', '', maxLength or 128)

    while UpdateOnscreenKeyboard() == 0 do
        DisableAllControlActions(0)
        Wait(0)
    end

    if GetOnscreenKeyboardResult() then
        return GetOnscreenKeyboardResult()
    end

    return nil
end

local function parseCoordinateInput(rawValue)
    if type(rawValue) ~= 'string' then
        return nil, 'Enter coordinates in the format: x, y, z'
    end

    local normalized = rawValue:gsub('[%c\r\n\t]', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if normalized == '' then
        return nil, 'Enter coordinates in the format: x, y, z'
    end

    local values = {}
    for value in normalized:gmatch('[^,]+') do
        local trimmed = value:gsub('^%s+', ''):gsub('%s+$', '')
        if trimmed ~= '' then
            values[#values + 1] = trimmed
        end
    end

    if #values ~= 3 then
        return nil, 'Use exactly three values: x, y, z'
    end

    local x = tonumber(values[1])
    local y = tonumber(values[2])
    local z = tonumber(values[3])

    if not x or not y or not z then
        return nil, 'Coordinates must be valid numbers'
    end

    return {
        x = x,
        y = y,
        z = z
    }
end

local function requestCustomTeleport()
    local rawCoords = promptTextInput('Enter coords: x, y, z', '', 128)
    if not rawCoords then
        return
    end

    local coords, errorMessage = parseCoordinateInput(rawCoords)
    if not coords then
        notifyPlayer(errorMessage)
        return
    end

    TriggerServerEvent('lsrp_dev:server:requestPrivilegedAction', 'tp', {
        action = 'tp',
        x = coords.x,
        y = coords.y,
        z = coords.z
    })
end

-- Player name based on framework
local function getPlayerName()
    local data = Framework:GetPlayerData()

    if Framework.Type == 'qbx' or Framework.Type == 'qbcore' then
        if data.charinfo then
            return data.charinfo.firstname .. ' ' .. data.charinfo.lastname
        end
    elseif Framework.Type == 'esx' then
        if data.firstName then
            return data.firstName .. ' ' .. data.lastName
        end
    end

    return GetPlayerName(PlayerId())
end

-- Player server ID
local function getPlayerId()
    return GetPlayerServerId(PlayerId())
end

-- Send player data to NUI
local function sendPlayerData()
    SendNUIMessage({
        action = 'setPlayerData',
        data = {
            name = getPlayerName(),
            id = tostring(getPlayerId())
        }
    })
end

-- Send default commands from config to NUI
local function sendDefaultCommands()
    local defaults = Config.DefaultCommands or {}
    local cmdMenu = Config.CommandMenu or {}
    SendNUIMessage({
        action = 'setDefaultCommands',
        data = defaults,
        commandMenuEnabled = cmdMenu.enabled ~= false
    })
end

-- Send locale from config to NUI
local function sendLocale()
    SendNUIMessage({
        action = 'setLocale',
        data = {
            locale = Config.Locale or "en"
        }
    })
end

-- Capture ped headshot (mugshot)
local function captureMugshot()
    local ped = PlayerPedId()

    if currentMugshot then
        UnregisterPedheadshot(currentMugshot)
        currentMugshot = nil
    end

    local handle = RegisterPedheadshot(ped)

    local timeout = 50
    while not IsPedheadshotReady(handle) and timeout > 0 do
        Wait(100)
        timeout = timeout - 1
    end

    if not IsPedheadshotReady(handle) then
        UnregisterPedheadshot(handle)
        return nil
    end

    currentMugshot = handle
    local txd = GetPedheadshotTxdString(handle)

    SendNUIMessage({
        action = 'setMugshot',
        data = {
            txd = txd
        }
    })

    return txd
end

local function deepcopy(orig, skipPermCheck)
    if type(orig) ~= 'table' then
        return orig
    end

    if not skipPermCheck and orig.canOpen and type(orig.canOpen) == 'function' then
        if not orig.canOpen() then
            return nil
        end
    end

    local copy = {}
    for key, value in pairs(orig) do
        if key == 'canOpen' then
            copy[key] = value
        else
            local copied_value = deepcopy(value, true)
            if copied_value ~= nil then
                copy[key] = copied_value
            end
        end
    end

    local mt = getmetatable(orig)
    if mt then
        setmetatable(copy, deepcopy(mt, true))
    end

    return copy
end

local function setupVehicleMenu()
    local vehicle = getNearestVeh()
    if not vehicle then return {} end

    local items = {}

    local doorItems = {}
    for i = 0, 5 do
        if DoesVehicleHaveDoor(vehicle, i) then
            table.insert(doorItems, {
                id = 'door' .. i,
                label = VehicleDoorLabels[i] or 'Door ' .. (i + 1),
                icon = 'door-open',
                event = 'codem-radialmenu:client:ToggleDoor',
                type = 'client',
                args = { door = i },
                shouldClose = false
            })
        end
    end

    if #doorItems > 0 then
        table.insert(items, {
            id = 'doors',
            label = 'Doors',
            icon = 'door-open',
            items = doorItems
        })
    end

    local seatItems = {}
    for i = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        if IsVehicleSeatFree(vehicle, i) then
            local seatLabel = i == -1 and 'Driver' or 'Seat ' .. (i + 2)
            table.insert(seatItems, {
                id = 'seat' .. i,
                label = seatLabel,
                icon = 'chair',
                event = 'codem-radialmenu:client:ChangeSeat',
                type = 'client',
                args = { seat = i },
                shouldClose = true
            })
        end
    end

    if #seatItems > 0 then
        table.insert(items, {
            id = 'seats',
            label = 'Seats',
            icon = 'chair',
            items = seatItems
        })
    end

    -- Vehicle extras (configurable via Config.VehicleMenu.EnableExtras)
    if Config.VehicleMenu and Config.VehicleMenu.EnableExtras then
        local extraItems = {}
        local extraCount = 0
        for i = 0, 12 do
            if DoesExtraExist(vehicle, i) then
                extraCount = extraCount + 1
                local isOn = IsVehicleExtraTurnedOn(vehicle, i)
                table.insert(extraItems, {
                    id = 'extra' .. i,
                    label = 'Extra ' .. extraCount .. (isOn and ' (On)' or ' (Off)'),
                    icon = isOn and 'toggle-on' or 'toggle-off',
                    event = 'codem-radialmenu:client:ToggleExtra',
                    type = 'client',
                    args = { extra = i },
                    shouldClose = false
                })
            end
        end

        if #extraItems > 0 then
            table.insert(items, {
                id = 'extras',
                label = 'Extras',
                icon = 'sliders',
                items = extraItems
            })
        end
    end

    table.insert(items, {
        id = 'flip',
        label = 'Flip Vehicle',
        icon = 'rotate',
        event = 'codem-radialmenu:client:FlipVehicle',
        type = 'client',
        shouldClose = true
    })

    return items
end

local function setupJobMenu()
    local job = Framework:GetPlayerJob()

    if not job or not job.name or job.name == 'unemployed' then
        return nil
    end

    if not job.onduty then
        return nil
    end

    local jobMenu = JobInteractions[job.name]
    if not jobMenu then
        return nil
    end

    if jobMenu.canOpen and not jobMenu.canOpen() then
        return nil
    end

    local copied = deepcopy(jobMenu)
    if not copied then
        return nil
    end

    -- Support both formats:
    -- Format 1 (wrapper): { id = 'police', label = 'Police Actions', items = {...} }
    -- Format 2 (array):   { {id = 'tablet', title = 'Tablet'}, {id = 'dispatch', title = 'Dispatch'} }
    if copied.items then
        -- Format 1: already has wrapper, just ensure label/title compatibility
        copied.label = copied.label or copied.title or 'Job Actions'
        return copied
    else
        -- Format 2: array of items, wrap it
        return {
            id = job.name,
            label = job.label or job.name:gsub("^%l", string.upper),
            icon = 'briefcase',
            items = copied
        }
    end
end

local function buildMenuItems()
    FinalMenuItems = {}

    local isDead = Framework:IsDead()
    local devConfig = Config.DevOnlyMenu or {}

    if isDead and devConfig.disableEmergencyOverride ~= true then
        table.insert(FinalMenuItems, {
            id = 'emergency',
            label = 'Call Emergency',
            icon = 'phone',
            event = 'hospital:client:CallEmergency',
            type = 'client',
            shouldClose = true
        })
        return
    end

    -- Auto-iterate all MenuItems array (citizen, general, blips, etc.)
    -- Just add/remove items in shared/items.lua - no main.lua changes needed
    for _, menuData in ipairs(MenuItems) do
        local copiedMenu = deepcopy(menuData)
        if copiedMenu then
            table.insert(FinalMenuItems, copiedMenu)
        end
    end

    -- Command category from config - items will be filled by Vue from localStorage
    local cmdMenu = Config.CommandMenu or {}
    if devConfig.disableCommandMenu ~= true and cmdMenu.enabled ~= false then
        table.insert(FinalMenuItems, {
            id = cmdMenu.id or 'commands',
            label = cmdMenu.label or cmdMenu.title or 'Command',
            icon = cmdMenu.icon or 'terminal',
            items = {}
        })
    end

    local jobMenu = setupJobMenu()
    if devConfig.disableJobMenu ~= true and jobMenu then
        table.insert(FinalMenuItems, jobMenu)
    end

    local vehicleItems = setupVehicleMenu()
    if devConfig.disableVehicleMenu ~= true and #vehicleItems > 0 then
        table.insert(FinalMenuItems, {
            id = 'vehicle',
            label = 'Vehicle',
            icon = 'car',
            items = vehicleItems
        })
    end

    for _, item in pairs(DynamicMenuItems) do
        local copiedItem = deepcopy(item)
        if copiedItem then
            table.insert(FinalMenuItems, copiedItem)
        end
    end
end

local function requestDevPermission(force)
    local devConfig = Config.DevOnlyMenu or {}
    local cacheTtl = devConfig.permissionCacheTtl or 15000
    local now = GetGameTimer()

    if not force and CodemDevAccess.loaded and (now - (CodemDevAccess.lastRefreshAt or 0)) < cacheTtl then
        return false
    end

    TriggerServerEvent('codem-supreme-radialmenu:server:requestDevPermission')
    return true
end

local function convertToNUIFormat(items)
    local converted = {}
    local idCounter = 1

    for _, item in ipairs(items) do
        local nuiItem = {
            id = idCounter,
            label = item.label or item.title,
            icon = item.icon,
            action = item.id
        }

        if item.items then
            nuiItem.items = convertToNUIFormat(item.items)
        end

        table.insert(converted, nuiItem)
        idCounter = idCounter + 1
    end

    return converted
end

local function openRadialMenu()
    if isMenuOpen then return end
    if IsPauseMenuActive() then return end

    local devConfig = Config.DevOnlyMenu or {}
    if devConfig.enabled == true and not CodemDevAccess.loaded then
        pendingOpenAfterPermission = true
        requestDevPermission(true)
        notifyPlayer('Checking dev access...')
        return
    end

    buildMenuItems()

    if #FinalMenuItems == 0 then
        if devConfig.enabled == true then
            notifyPlayer(CodemDevAccess.denialMessage or 'You do not have dev admin rights.')
            requestDevPermission(true)
        end
        return
    end

    local nuiItems = convertToNUIFormat(FinalMenuItems)

    SetCursorLocation(0.5, 0.5)
    SetNuiFocus(true, true)
    -- In hold mode, keep keyboard input so we can detect key release
    if radialBehaviour == 'hold' then
        SetNuiFocusKeepInput(true)
    end
    sendLocale()
    SendNUIMessage({
        action = 'openMenu',
        items = nuiItems
    })

    isMenuOpen = true
end

local function closeRadialMenu()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    if isMenuOpen then
        SendNUIMessage({
            action = 'closeMenu'
        })
        isMenuOpen = false
    end
end

-- Thread to disable player controls in hold mode while menu is open
CreateThread(function()
    while true do
        if isMenuOpen and radialBehaviour == 'hold' then
            -- Disable all controls (including camera movement)
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- Key mappings for radial menu
RegisterKeyMapping('+radialmenu', 'Open Radial Menu', 'keyboard', 'F3')
RegisterKeyMapping('-radialmenu', 'Close Radial Menu (Hold Mode)', 'keyboard', '')

-- Open menu (key pressed)
RegisterCommand('+radialmenu', function()
    if not isMenuOpen then
        openRadialMenu()
    end
end, false)

-- Close menu (key released) - only works in hold mode
RegisterCommand('-radialmenu', function()
    if radialBehaviour == 'hold' and isMenuOpen then
        closeRadialMenu()
    end
end, false)

RegisterCommand('radialsettings', function()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openSettings'
    })
    sendLocale()
    sendPlayerData()
    captureMugshot()
    sendDefaultCommands()
end, false)

RegisterNetEvent('codem-supreme-radialmenu:client:SetDevPermission', function(permissionState)
    permissionState = type(permissionState) == 'table' and permissionState or {}
    CodemDevAccess.loaded = true
    CodemDevAccess.isAuthorized = permissionState.isAuthorized == true
    CodemDevAccess.denialMessage = permissionState.denialMessage or 'You do not have dev admin rights.'
    CodemDevAccess.lastRefreshAt = GetGameTimer()

    if pendingOpenAfterPermission then
        pendingOpenAfterPermission = false
        openRadialMenu()
    end
end)

RegisterNetEvent('codem-supreme-radialmenu:client:RunLocalDevAction', function(data)
    local action = data and data.action or nil
    if action == 'pos' then
        ExecuteCommand('pos')
        return
    end

    if action == 'ids' then
        ExecuteCommand('ids')
        return
    end

    if action == 'noclip' then
        ExecuteCommand('noclip')
        return
    end

    if action == 'identityaudit' then
        ExecuteCommand('identityaudit')
        return
    end

    if action == 'tp_custom' then
        requestCustomTeleport()
    end
end)

RegisterNetEvent('codem-supreme-radialmenu:client:RequestDevAction', function(data)
    local action = data and data.action or nil
    if not action then
        return
    end

    TriggerServerEvent('lsrp_dev:server:requestPrivilegedAction', action, data)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    requestDevPermission(true)
end)

RegisterNUICallback('closeMenu', function(_, cb)
    closeRadialMenu()
    cb('ok')
end)

RegisterNUICallback('setRadialBehaviour', function(data, cb)
    if data and data.behaviour then
        if data.behaviour == 'hold' or data.behaviour == 'press' then
            radialBehaviour = data.behaviour
        end
    end
    cb('ok')
end)

-- Find menu item by id recursively
local function findMenuItem(items, targetId)
    for _, item in ipairs(items) do
        if item.id == targetId then
            return item
        end
        if item.items then
            local found = findMenuItem(item.items, targetId)
            if found then return found end
        end
    end
    return nil
end

RegisterNUICallback('selectItem', function(data, cb)
    -- Validate input data
    if not data or type(data) ~= 'table' then
        closeRadialMenu()
        cb('error')
        return
    end

    if not data.action or type(data.action) ~= 'string' then
        closeRadialMenu()
        cb('error')
        return
    end

    -- Prevent exploit with long strings
    if #data.action > 200 then
        closeRadialMenu()
        cb('error')
        return
    end

    local action = data.action

    -- Handle custom commands from Vue (starts with / or is a direct command)
    if string.sub(action, 1, 1) == '/' then
        closeRadialMenu()
        ExecuteCommand(string.sub(action, 2))
        cb('ok')
        return
    end

    -- Find the original menu item to check for event/shouldClose
    local menuItem = findMenuItem(FinalMenuItems, action)

    -- Handle shouldClose - only close if not specified or true
    if not menuItem or menuItem.shouldClose ~= false then
        closeRadialMenu()
    end

    -- Handle event-based items (doors, seats, extras, blips, etc.)
    if menuItem and menuItem.event then
        local eventData = { id = menuItem.id }
        if menuItem.args then
            for k, v in pairs(menuItem.args) do
                eventData[k] = v
            end
        end

        if menuItem.type == 'server' then
            TriggerServerEvent(menuItem.event, eventData)
        else
            TriggerEvent(menuItem.event, eventData)
        end
        cb('ok')
        return
    end

    cb('ok')
end)

exports('AddMenuItem', function(item)
    if not item or not item.id then
        return false
    end
    DynamicMenuItems[item.id] = item
    return true
end)

exports('RemoveMenuItem', function(itemId)
    if DynamicMenuItems[itemId] then
        DynamicMenuItems[itemId] = nil
        return true
    end
    return false
end)

local settingsPromise = nil

RegisterNUICallback('returnSettings', function(data, cb)
    if settingsPromise then
        settingsPromise(data)
        settingsPromise = nil
    end
    cb('ok')
end)

exports("GetSettings", function()
    local p = promise.new()
    settingsPromise = function(data) p:resolve(data) end
    SendNUIMessage({ action = "getSettings" })
    return Citizen.Await(p)
end)

exports("UpdateSettings", function(data)
    SendNUIMessage({ action = "updateSettings", data = data })
end)

-- Command management exports for HUD integration
local commandsPromise = nil

RegisterNUICallback('returnCustomCommands', function(data, cb)
    if commandsPromise then
        commandsPromise(data.commands or {})
        commandsPromise = nil
    end
    cb('ok')
end)

exports("GetCustomCommands", function()
    local p = promise.new()
    commandsPromise = function(data) p:resolve(data) end
    SendNUIMessage({ action = "getCustomCommands" })
    return Citizen.Await(p)
end)

exports("SetCustomCommands", function(commands)
    SendNUIMessage({ action = "setCustomCommands", data = commands })
end)

exports("IsCommandMenuEnabled", function()
    return (Config.CommandMenu or {}).enabled ~= false
end)

exports("GetDefaultCommands", function()
    return Config.DefaultCommands or {}
end)

-- Open radial settings (NUI settings page)
RegisterNetEvent('codem-radialmenu:client:OpenSettings', function()
    SendNUIMessage({
        action = 'openSettings'
    })
    SetNuiFocus(true, true)
    sendLocale()
    sendPlayerData()
    captureMugshot()
    sendDefaultCommands()
end)

