Config = {}

-- Key to press when inside a zone (38 = E)
Config.OpenKey = 38

-- Show CircleZone debug outlines in-game (false for production)
Config.DebugZones = false

-- Zone definitions.
-- action: the local event name fired when the player presses E.
--         Must match a RegisterNetEvent / AddEventHandler in the target resource.
-- blip.sprite / blip.color: see https://docs.fivem.net/docs/game-references/blips/
Config.Zones = {
    {
        name       = "Clothing Store",
        prompt     = "Press ~INPUT_CONTEXT~ to open clothing editor",
        coords     = vector3(425.52, -805.10, 29.49),
        radius     = 3.5,
        action     = "lsrp_pededitor:open",
        blip = {
            sprite = 73,
            color  = 9,
            scale  = 0.8,
            label  = "Clothing Store"
        }
    },
    {
        name       = "Clothing Store",
        prompt     = "Press ~INPUT_CONTEXT~ to open clothing editor",
        coords     = vector3(124.02, -219.81, 54.56),
        radius     = 3.5,
        action     = "lsrp_pededitor:open",
        blip = {
            sprite = 73,
            color  = 9,
            scale  = 0.8,
            label  = "Clothing Store"
        }
    },
    {
        name       = "Clothing Store",
        prompt     = "Press ~INPUT_CONTEXT~ to open clothing editor",
        coords     = vector3(76.22, -1392.84, 29.38),
        radius     = 3.5,
        action     = "lsrp_pededitor:open",
        blip = {
            sprite = 73,
            color  = 9,
            scale  = 0.8,
            label  = "Clothing Store"
        }
    },
        {
        name       = "Clothing Store",
        prompt     = "Press ~INPUT_CONTEXT~ to open clothing editor",
        coords     = vector3(617.65, 2760.04, 42.09),
        radius     = 3.5,
        action     = "lsrp_pededitor:open",
        blip = {
            sprite = 73,
            color  = 9,
            scale  = 0.8,
            label  = "Clothing Store"
        }
    },
    {
        name       = "Vehicle Mod Shop",
        prompt     = "Press ~INPUT_CONTEXT~ to open vehicle editor",
        coords     = vector3(-212.19, -1324.22, 30.89),
        radius     = 4.0,
        action     = "lsrp_vehicleeditor:open",
        blip = {
            sprite = 446,  -- LS Customs wrench/star icon
            color  = 3,    -- blue
            scale  = 0.8,
            label  = "Vehicle Mod Shop"
        }
    },
    {
        name       = "Vehicle Mod Shop",
        prompt     = "Press ~INPUT_CONTEXT~ to open vehicle editor",
        coords     = vector3(-337.70, -136.13, 38.43),
        radius     = 4.0,
        action     = "lsrp_vehicleeditor:open",
        blip = {
            sprite = 446,  -- LS Customs wrench/star icon
            color  = 3,    -- blue
            scale  = 0.8,
            label  = "Vehicle Mod Shop"
        }
    }
}