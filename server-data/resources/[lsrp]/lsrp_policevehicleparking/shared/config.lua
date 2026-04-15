Config = Config or {}

Config.Debug = false

Config.ParkingZones = {
    {
        name = 'Mission Row Police Garage',
        coords = vector3(458.36, -1019.09, 28.19),
        size = vector3(14.0, 16.0, 4.0),
        rotation = 90.0,
        maxSlots = 8,
        allowedJobs = { 'police_officer' },
        blip = {
            sprite = 357,
            color = 38,
            scale = 0.8,
            label = 'MRPD Fleet Garage'
        },
        spawnPoints = {
            { coords = vector3(454.29, -1017.42, 28.42), heading = 90.0 },
            { coords = vector3(454.29, -1023.24, 28.42), heading = 90.0 },
            { coords = vector3(462.74, -1019.86, 28.1), heading = 90.0 }
        }
    },
    {
        name = 'Pillbox Ambulance Garage',
        coords = vector3(294.36, -611.32, 43.35),
        size = vector3(10.0, 16.0, 4.0),
        rotation = 70.0,
        maxSlots = 6,
        allowedJobs = { 'ems_responder' },
        blip = {
            sprite = 357,
            color = 1,
            scale = 0.8,
            label = 'Pillbox Ambulance Garage'
        },
        spawnPoints = {
            { coords = vector3(289.62, -612.99, 43.3), heading = 70.0 },
            { coords = vector3(292.24, -607.24, 43.3), heading = 70.0 },
            { coords = vector3(296.02, -601.86, 43.3), heading = 70.0 }
        }
    }
}

Config.FleetCatalog = {
    police_officer = {
        {
            id = 'mission_row_cruiser_1',
            label = 'Patrol Cruiser',
            vehicleModel = 'police3',
            platePrefix = 'LSPD',
            parkingZone = 'Mission Row Police Garage'
        },
        {
            id = 'mission_row_cruiser_2',
            label = 'Patrol Cruiser',
            vehicleModel = 'police3',
            platePrefix = 'LSPD',
            parkingZone = 'Mission Row Police Garage'
        }
    },
    ems_responder = {
        {
            id = 'pillbox_ambulance_1',
            label = 'Ambulance',
            vehicleModel = 'ambulance',
            platePrefix = 'EMS',
            parkingZone = 'Pillbox Ambulance Garage'
        },
        {
            id = 'pillbox_ambulance_2',
            label = 'Ambulance',
            vehicleModel = 'ambulance',
            platePrefix = 'EMS',
            parkingZone = 'Pillbox Ambulance Garage'
        }
    }
}

Config.OpenKey = 38
Config.showParkingZoneDebug = false

Config.StorageFee = 0
Config.RetrievalFee = 0

Config.VehicleStorage = {
    enabled = true,
    commandName = 'emvehstorage',
    defaultKey = 'G',
    keyLabel = 'G',
    openDistance = 2.5,
    rearOffsetPadding = 0.75,
    serverValidationRange = 10.0,
    slots = 24,
    maxWeight = 35000,
    displayName = 'Fleet Trunk'
}
