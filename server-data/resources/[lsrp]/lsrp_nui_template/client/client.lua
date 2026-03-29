local uiOpen = false

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

RegisterNUICallback('close', function(_, cb)
    closeTemplateUi()
    cb({ ok = true })
end)

RegisterNUICallback('primaryAction', function(data, cb)
    print(('[lsrp_nui_template] primary action: %s'):format(json.encode(data or {})))
    cb({ ok = true })
end)

RegisterNUICallback('secondaryAction', function(data, cb)
    print(('[lsrp_nui_template] secondary action: %s'):format(json.encode(data or {})))
    cb({ ok = true })
end)

RegisterCommand('nui_template_preview', function()
    openTemplateUi({
        eyebrow = 'LSRP Template',
        title = 'Reusable NUI Shell',
        subtitle = 'Transparent root, hidden startup, and a centered panel shell.',
        statusItems = {
            { label = 'Mode', value = 'Preview' },
            { label = 'Focus', value = 'Mouse + Keyboard' }
        },
        sections = {
            {
                title = 'Why this exists',
                body = 'Use this as the starting point for any new LSRP NUI so you do not have to rediscover the transparent backdrop rules.'
            },
            {
                title = 'Safe defaults',
                body = 'The page starts hidden, body stays transparent, and only the root app is shown when the UI is opened.'
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