local function isMinimapEnabled()
    if not lsrpConfig then
        return true
    end

    return lsrpConfig.minimapEnabled ~= false
end

local function isLoadingIndicatorEnabled()
    if not lsrpConfig then
        return true
    end

    return lsrpConfig.loadingIndicatorEnabled ~= false
end

local function hideMinimapFrame()
    DisplayRadar(false)
    SetBigmapActive(false, false)
    HideHudComponentThisFrame(6)
    HideHudComponentThisFrame(7)
    HideHudComponentThisFrame(8)
    HideHudComponentThisFrame(9)
end

local function hideLoadingIndicatorFrame()
    if type(BusyspinnerOff) == 'function' then
        BusyspinnerOff()
    end

    if type(RemoveLoadingPrompt) == 'function' then
        RemoveLoadingPrompt()
    end

    HideHudComponentThisFrame(17)
end

CreateThread(function()
    while true do
        if not isMinimapEnabled() then
            hideMinimapFrame()
        end

        if not isLoadingIndicatorEnabled() then
            hideLoadingIndicatorFrame()
        end

        if not isMinimapEnabled() or not isLoadingIndicatorEnabled() then
            Wait(0)
        else
            Wait(500)
        end
    end
end)