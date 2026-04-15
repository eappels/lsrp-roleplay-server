Config = {
    -- Locale setting
    Locale = "en", -- Available: "en", "tr"

    DevOnlyMenu = {
        enabled = true,
        permissionCacheTtl = 15000,
        disableEmergencyOverride = true,
        disableCommandMenu = true,
        disableJobMenu = true,
        disableVehicleMenu = true,
    },

    -- Command menu category settings (the "Command" button in radial menu)
    -- Players can add their own commands via settings panel
    -- Set enabled = false to completely disable command menu and settings customization
    CommandMenu = {
        enabled = false,
        id = "commands",
        label = "Command",
        icon = "terminal",
    },

    -- Default commands for radial menu (shown when player clicks "Revert To Default")
    -- Players can customize these in settings, this is just the starting point
    -- icon: FontAwesome icon name (e.g., 'phone', 'box', 'car', 'wallet', 'briefcase')
    -- command: The command to execute (with or without leading /)
    DefaultCommands = {
        { label = "Phone",     icon = "phone",      command = "/phone" },
        { label = "Inventory", icon = "box",        command = "/inventory" },
        { label = "Wallet",    icon = "wallet",     command = "/wallet" },
        { label = "Emotes",    icon = "face-smile", command = "/emotes" },
    },

    -- Vehicle menu settings
    VehicleMenu = {
        EnableExtras = true, -- Show vehicle extras (Extra 1-13) in vehicle menu
    },

    -- Distance settings
    Distances = {
        VehicleInteraction = 5.0, -- Max distance for vehicle interactions
        TrunkEntry = 3.0,         -- Max distance to enter trunk
    },

    -- Gameplay limits
    Limits = {
        MaxSpeedForSeatChange = 100.0, -- km/h - Max speed to allow seat changes
        MaxMenuItems = 8,              -- Max items per menu level
    },

    -- Cache settings
    Cache = {
        PlayerDataTTL = 1000,   -- ms - How long to cache player data
        VehicleMenuTTL = 30000, -- ms - How long to cache vehicle menu
    },

    -- Trunk system settings
    TrunkClasses = {
        [0] = { allowed = true, x = 0.0, y = -1.5, z = 0.0 },    -- Compacts
        [1] = { allowed = true, x = 0.0, y = -2.0, z = 0.0 },    -- Sedans
        [2] = { allowed = true, x = 0.0, y = -1.0, z = 0.25 },   -- SUVs
        [3] = { allowed = true, x = 0.0, y = -1.5, z = 0.0 },    -- Coupes
        [4] = { allowed = true, x = 0.0, y = -2.0, z = 0.0 },    -- Muscle
        [5] = { allowed = true, x = 0.0, y = -2.0, z = 0.0 },    -- Sports Classics
        [6] = { allowed = true, x = 0.0, y = -2.0, z = 0.0 },    -- Sports
        [7] = { allowed = true, x = 0.0, y = -2.0, z = 0.0 },    -- Super
        [8] = { allowed = false, x = 0.0, y = -1.0, z = 0.25 },  -- Motorcycles
        [9] = { allowed = true, x = 0.0, y = -1.0, z = 0.25 },   -- Off-road
        [10] = { allowed = true, x = 0.0, y = -1.0, z = 0.25 },  -- Industrial
        [11] = { allowed = true, x = 0.0, y = -1.0, z = 0.25 },  -- Utility
        [12] = { allowed = true, x = 0.0, y = -1.0, z = 0.25 },  -- Vans
        [13] = { allowed = false, x = 0.0, y = -1.0, z = 0.25 }, -- Cycles
        [14] = { allowed = false, x = 0.0, y = -1.0, z = 0.25 }, -- Boats
        [15] = { allowed = false, x = 0.0, y = -1.0, z = 0.25 }, -- Helicopters
        [16] = { allowed = false, x = 0.0, y = -1.0, z = 0.25 }, -- Planes
        [17] = { allowed = true, x = 0.0, y = -1.0, z = 0.25 },  -- Service
        [18] = { allowed = true, x = 0.0, y = -1.0, z = 0.25 },  -- Emergency
        [19] = { allowed = true, x = 0.0, y = -1.0, z = 0.25 },  -- Military
        [20] = { allowed = true, x = 0.0, y = -1.0, z = 0.25 },  -- Commercial
        [21] = { allowed = false, x = 0.0, y = -1.0, z = 0.25 }  -- Trains
    },
}
