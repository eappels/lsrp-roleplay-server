local uiOpen = false

local function notify(message, level)
    exports.lsrp_framework:notify(message, level)
end

local function closeTemplateUi()
    if not uiOpen then
        return
    end

    uiOpen = false
    SetNuiFocus(false, false)
    if type(SetNuiFocusKeepInput) == 'function' then
        SetNuiFocusKeepInput(false)
    end

    SendNUIMessage({ action = 'close' })
end

local function openTemplateUi(payload)
    if uiOpen then
        closeTemplateUi()
    end

    uiOpen = true
    SetNuiFocus(true, true)
    if type(SetNuiFocusKeepInput) == 'function' then
        SetNuiFocusKeepInput(false)
    end

    SendNUIMessage({
        action = 'open',
        payload = payload or {}
    })
end

exports.lsrp_framework:registerNuiCallback('close', function()
    closeTemplateUi()
    return true
end)

exports.lsrp_framework:registerNuiCallback('primaryAction', function(data)
    print(('[lsrp_nui_template] primary action: %s'):format(json.encode(data or {})))
    notify('Template primary action fired.', 'success')
    return true, {
        event = data and data.event or 'primary'
    }
end)

exports.lsrp_framework:registerNuiCallback('secondaryAction', function(data)
    print(('[lsrp_nui_template] secondary action: %s'):format(json.encode(data or {})))
    if data and data.event == 'preview-close' then
        closeTemplateUi()
    end

    return true, {
        event = data and data.event or 'secondary'
    }
end)

RegisterCommand('nui_template_preview', function()
    openTemplateUi({
        eyebrow = 'LSRP Template',
        title = 'Reusable NUI Shell',
        subtitle = 'Transparent root, hidden startup, centered shell, and framework-backed NUI callbacks.',
        statusItems = {
            { label = 'Mode', value = 'Preview' },
            { label = 'Focus', value = 'Mouse + Keyboard' },
            { label = 'Callbacks', value = 'lsrp_framework' }
        },
        sections = {
            {
                title = 'Why this exists',
                body = 'Use this as the starting point for any new LSRP NUI so you do not have to rediscover the transparent backdrop rules.'
            },
            {
                title = 'Safe defaults',
                body = 'The page starts hidden, body stays transparent, and only the root app is shown when the UI is opened.'
            },
            {
                title = 'Framework-first actions',
                body = 'The sample buttons use lsrp_framework NUI callback registration so copied resources inherit the supported callback contract.'
            }
        },
        primary = { label = 'Primary Action', event = 'preview-primary' },
        secondary = { label = 'Close', event = 'preview-close' },
        footer = 'Press Escape or use the close button to dismiss the preview.'
    })
end, false)

RegisterCommand('nui_template_close', function()
    closeTemplateUi()
end, false)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    closeTemplateUi()
end)