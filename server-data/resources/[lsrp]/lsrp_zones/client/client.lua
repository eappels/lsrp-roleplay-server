-- LSRP Zone System - Client Script
--
-- Creates proximity CircleZones that show a context-key prompt and fire a
-- framework interaction when the player presses E. Zones and their target
-- interaction ids are
-- configured in shared/config.lua.
--
-- Current zones:
--   Clothing Store   -> lsrp_pededitor:open
--   Vehicle Mod Shop -> lsrp_vehicleeditor:open
--   Vehicle Shop     -> lsrp_vehicleshop:open

local activeZones = {}
local zoneBlips   = {}
local inZone      = false
local currentZone = nil
local suppressPrompt = false

local function invokeZoneInteraction(zoneCfg)
    if GetResourceState('lsrp_framework') ~= 'started' then
        return false
    end

    local interactionName = tostring(zoneCfg and (zoneCfg.interaction or zoneCfg.action) or '')
    if interactionName == '' then
        return false
    end

    local ok, response = pcall(function()
        return exports['lsrp_framework']:invokeInteraction(interactionName, {
            zone = {
                name = zoneCfg.name,
                prompt = zoneCfg.prompt,
                coords = zoneCfg.coords,
                radius = zoneCfg.radius
            }
        })
    end)

    if not ok or type(response) ~= 'table' or response.ok ~= true then
        print(('[lsrp_zones] Failed to invoke interaction %s: %s'):format(interactionName, tostring(response and response.error or 'no_response')))
        return false
    end

    return true
end

AddEventHandler('lsrp_vehicleeditor:opened',  function() suppressPrompt = true  end)
AddEventHandler('lsrp_vehicleeditor:closed',  function() suppressPrompt = false end)
AddEventHandler('lsrp_pededitor:opened',      function() suppressPrompt = true  end)
AddEventHandler('lsrp_pededitor:closed',      function() suppressPrompt = false end)

-- ---------------------------------------------------------------------------
-- Zone lifecycle
-- ---------------------------------------------------------------------------

local function destroyZones()
    for i = 1, #activeZones do
        local zone = activeZones[i]
        if zone and type(zone.destroy) == 'function' then
            zone:destroy()
        end
    end
    activeZones = {}

    for i = 1, #zoneBlips do
        RemoveBlip(zoneBlips[i])
    end
    zoneBlips = {}
end

local function createZones()
    destroyZones()

    if type(CircleZone) ~= 'table' or type(CircleZone.Create) ~= 'function' then
        print('[lsrp_zones] CircleZone is not available. Ensure polyzone is started before lsrp_zones.')
        return
    end

    for _, zoneCfg in ipairs(Config.Zones) do
        local zone = CircleZone:Create(zoneCfg.coords, zoneCfg.radius, {
            name     = zoneCfg.name,
            useZ     = true,
            debugPoly = Config.DebugZones == true
        })

        zone:onPlayerInOut(function(isInside)
            if isInside then
                inZone      = true
                currentZone = zoneCfg
            else
                if currentZone and currentZone.name == zoneCfg.name then
                    inZone      = false
                    currentZone = nil
                end
            end
        end)

        activeZones[#activeZones + 1] = zone
        print(('[lsrp_zones] Created zone: %s'):format(zoneCfg.name))

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
            zoneBlips[#zoneBlips + 1] = blip
        end
    end
end

-- ---------------------------------------------------------------------------
-- Initialization
-- ---------------------------------------------------------------------------

CreateThread(function()
    Wait(1000) -- Wait for polyzone to initialise
    createZones()
end)

-- ---------------------------------------------------------------------------
-- Interaction prompt thread
-- ---------------------------------------------------------------------------

CreateThread(function()
    while true do
        local sleep = 500

        if inZone and currentZone then
            sleep = 0

            if not suppressPrompt then
                BeginTextCommandDisplayHelp("STRING")
                AddTextComponentString(currentZone.prompt)
                EndTextCommandDisplayHelp(0, false, true, -1)
            end

            if IsControlJustReleased(0, Config.OpenKey) then
                invokeZoneInteraction(currentZone)
            end
        end

        Wait(sleep)
    end
end)

-- ---------------------------------------------------------------------------
-- Cleanup
-- ---------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        destroyZones()
    end
end)
