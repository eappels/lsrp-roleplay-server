Config = Config or {}

Config.InteractionKey = 38 -- E
Config.OpenPrompt = 'Press ~INPUT_CONTEXT~ to browse dealership inventory'
Config.AutoCloseDistance = 9.0
Config.PurchaseCooldownMs = 1750
Config.AdminCustomPurchaseAce = 'lsrp.vehicleshop.admin'
Config.AdminCustomUnlistedPrice = 0

Config.Marker = {
    enabled = true,
    type = 36,
    scale = vector3(0.85, 0.85, 0.85),
    color = { r = 255, g = 176, b = 46, a = 185 },
    bobUpAndDown = true,
    rotate = true
}

Config.DefaultDeliveryParkingZone = 'Legion Square'

Config.Plate = {
    prefix = 'LS',
    letters = 2,
    numbers = 3
}

Config.Categories = {
    { id = 'compact', label = 'Compact' },
    { id = 'sedan', label = 'Sedan' },
    { id = 'muscle', label = 'Muscle' },
    { id = 'sports', label = 'Sports' },
    { id = 'suv', label = 'SUV' },
    { id = 'offroad', label = 'Off-road' },
    { id = 'motorcycle', label = 'Motorcycle' }
}

Config.Shops = {
    {
        id = 'pdm',
        name = 'Premium Deluxe Motorsport',
        subtitle = 'Curated city inventory with garage delivery.',
        interaction = vector3(-56.86, -1096.75, 26.42),
        interactionRadius = 2.8,
        drawDistance = 25.0,
        deliveryParkingZone = 'PDM',
        allowedCategories = {
            'compact',
            'sedan',
            'muscle',
            'sports',
            'suv',
            'offroad',
            'motorcycle'
        },
        demoDisplays = {
            { model = 'asbo', x = -36.71, y = -1101.38, z = 26.42, heading = 159.44 },
            { model = 'blista', x = -43.75, y = -1095.79, z = 26.42, heading = 71.12 },
            { model = 'prairie', x = -48.01, y = -1099.62, z = 26.42, heading = 214.52 }
        },
        blip = {
            enabled = true,
            sprite = 326,
            color = 5,
            scale = 0.85,
            label = 'Vehicle Dealership'
        }
    }
}

Config.Vehicles = {
    { model = 'asbo', label = 'Asbo', category = 'compact', price = 18000, speed = 4, accel = 5, handling = 6, braking = 5 },
    { model = 'blista', label = 'Blista', category = 'compact', price = 14000, speed = 4, accel = 4, handling = 5, braking = 4 },
    { model = 'prairie', label = 'Prairie', category = 'compact', price = 17000, speed = 5, accel = 4, handling = 5, braking = 5 },

    { model = 'primo', label = 'Primo', category = 'sedan', price = 26000, speed = 4, accel = 4, handling = 5, braking = 5 },
    { model = 'stanier', label = 'Stanier', category = 'sedan', price = 29000, speed = 5, accel = 4, handling = 5, braking = 5 },
    { model = 'tailgater', label = 'Tailgater', category = 'sedan', price = 42000, speed = 6, accel = 6, handling = 6, braking = 6 },

    { model = 'dominator', label = 'Dominator', category = 'muscle', price = 54000, speed = 7, accel = 7, handling = 5, braking = 5 },
    { model = 'gauntlet', label = 'Gauntlet', category = 'muscle', price = 62000, speed = 7, accel = 6, handling = 6, braking = 5 },
    { model = 'buffalo', label = 'Buffalo', category = 'muscle', price = 68000, speed = 7, accel = 7, handling = 6, braking = 6 },

    { model = 'elegy2', label = 'Elegy RH8', category = 'sports', price = 88000, speed = 8, accel = 8, handling = 7, braking = 6 },
    { model = 'jester', label = 'Jester', category = 'sports', price = 112000, speed = 9, accel = 8, handling = 8, braking = 7 },
    { model = 'sultan', label = 'Sultan', category = 'sports', price = 94000, speed = 8, accel = 7, handling = 7, braking = 6 },
    { model = 'comet2', label = 'Comet', category = 'sports', price = 129000, speed = 9, accel = 8, handling = 8, braking = 7 },

    { model = 'baller2', label = 'Baller', category = 'suv', price = 72000, speed = 6, accel = 6, handling = 5, braking = 5 },
    { model = 'rebla', label = 'Rebla GTS', category = 'suv', price = 98000, speed = 7, accel = 7, handling = 6, braking = 6 },
    { model = 'granger', label = 'Granger', category = 'suv', price = 84000, speed = 6, accel = 5, handling = 5, braking = 5 },

    { model = 'mesa', label = 'Mesa', category = 'offroad', price = 64000, speed = 6, accel = 6, handling = 6, braking = 5 },
    { model = 'sandking', label = 'Sandking XL', category = 'offroad', price = 79000, speed = 6, accel = 5, handling = 6, braking = 5 },

    { model = 'faggio', label = 'Faggio', category = 'motorcycle', price = 7000, speed = 3, accel = 3, handling = 4, braking = 4 },
    { model = 'akuma', label = 'Akuma', category = 'motorcycle', price = 56000, speed = 8, accel = 8, handling = 7, braking = 6 },
    { model = 'bati', label = 'Bati 801', category = 'motorcycle', price = 68000, speed = 9, accel = 9, handling = 7, braking = 6 }
}
