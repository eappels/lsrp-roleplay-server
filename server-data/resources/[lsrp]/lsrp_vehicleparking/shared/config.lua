Config = {}

-- Parking zones configuration
-- Optional per-zone retrieval spawn:
-- preferredSpawn = {
--     coords = vector3(x, y, z),
--     heading = 0.0,
--     clearRadius = 3.0
-- }
Config.ParkingZones = {
    {
        name = "Legion Square",
        coords = vector3(222, -796.5, 30.7),
        size = vector3(10.0, 20.0, 3.0),
        rotation = 70.0,
        maxSlots = 10,
        blip = {
            sprite = 357,
            color = 3,
            scale = 0.8,
            label = "Legion Square"
        }
    },
    {
        name = "Tow recovery unrepaired",
        coords = vector3(419.88, -1639.62, 29.29),
        size = vector3(5.0, 10.0, 3.0),
        rotation = 90.0,
        maxSlots = 1000,
        blip = {
            sprite = 357,
            color = 7,
            scale = 0.8,
            label = "Tow recovery unrepaired"
        }
    },
    {
        name = "Airport",
        coords = vector3(-796.9, -2024.5, 9.2),
        size = vector3(30.0, 30.0, 3.0),
        rotation = 135.0,
        maxSlots = 20,
        blip = {
            sprite = 357,
            color = 3,
            scale = 0.8,
            label = "Airport"
        }
    },
    {
        name = "Downtown",
        coords = vector3(-308.24, -986.68, 31.08),
        size = vector3(6.0, 25.0, 3.0),
        rotation = 340.0,
        maxSlots = 15,
        blip = {
            sprite = 357,
            color = 3,
            scale = 0.8,
            label = "Downtown"
        }
    },
    {
        name = "Eclipse Towers",
        coords = vector3(-751.0, 373.60, 87.87),
        size = vector3(6.0, 20.0, 3.0),
        rotation = 180,
        maxSlots = 15,
        preferredSpawn = {
            coords = vector3(-746.07, 373.51, 87.87),
            heading = 4.99,
            clearRadius = 3.0
        },
        blip = {
            sprite = 357,
            color = 3,
            scale = 0.8,
            label = "Eclipse Towers"
        }
    },
    -- {
    --     name = "Alta",
    --     coords = vector3(282.96, -333.44, 44.92),
    --     size = vector3(13.0, 20.0, 3.0),
    --     rotation = 68.0,
    --     maxSlots = 10,
    --     blip = {
    --         sprite = 357,
    --         color = 3,
    --         scale = 0.8,
    --         label = "Alta"
    --     }
    -- },
    {
        name = "PDM",
        coords = vector3(-50.33, -1116.51, 26.43),
        size = vector3(6.0, 20.0, 3.0),
        rotation = 0.0,
        maxSlots = 10,
        allowStore = false,
        preferredSpawn = {
            coords = vector3(-43.82, -1098.73, 26.42),
            heading = 71.5,
            clearRadius = 3.0
        },
        blip = {
            sprite = 357,
            color = 7,
            scale = 0.8,
            label = "PDM"
        }
    },
    {
        name = "LS Customs",
        coords = vector3(-384.26, -134.23, 38.69),
        size = vector3(6.0, 20.0, 3.0),
        rotation = 120.0,
        maxSlots = 10,
        preferredSpawn = {
            coords = vector3(-386.21, -131.60, 38.68),
            heading = 116.84,
            clearRadius = 3.0
        },
        blip = {
            sprite = 357,
            color = 3,
            scale = 0.8,
            label = "LS Customs"
        }
    }
}

-- UI settings
Config.OpenKey = 38 -- E key
Config.showParkingZoneDebug = false -- true shows BoxZone boundaries

-- Vehicle storage settings
Config.StorageFee = 0 -- LS$ fee to store a vehicle (whole dollars only, set to 0 for free)
Config.RetrievalFee = 50 -- LS$ fee to retrieve a vehicle (whole dollars only, set to 0 for free)

Config.VehicleStorage = {
    enabled = true,
    commandName = 'vehstorage',
    defaultKey = 'G',
    keyLabel = 'G',
    openDistance = 2.5,
    rearOffsetPadding = 0.75,
    serverValidationRange = 10.0,
    slots = 24,
    maxWeight = 35000,
    displayName = 'Trunk'
}
