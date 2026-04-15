Config = Config or {}

Config.DefaultTankCapacity = 65.0
Config.MinTankCapacity = 5.0
Config.MaxTankCapacity = 200.0
Config.EmptyFuelThreshold = 0.1
Config.RefuelControl = 38
Config.PumpScanRadius = 5.0
Config.PumpInteractDistance = 2.75
Config.EVChargerScanRadius = 8.0
Config.EVChargerInteractDistance = 4.5
Config.EVChargerLocationInteractDistance = 2.75
Config.EVChargingStationRadius = 10.0
Config.VehicleSearchRadius = 4.0
Config.PumpVehicleDistance = 6.0
Config.EVChargerVehicleDistance = 8.0
Config.EVChargerLocationVehicleDistance = 6.0
Config.FullRefuelDurationMs = 60000
Config.MinRefuelDurationMs = 1500
Config.FullEVChargeDurationMultiplier = 3.0
Config.MinEVChargeDurationMs = 1500
Config.EVChargeFastThresholdPercent = 80.0
Config.EVChargeFastPhaseTimeShare = 0.6
Config.RefuelCostPerUnit = 2
Config.FuelRevenueLicense = 'business:fuel'
Config.RefuelAnimationMode = 'anim'
Config.RefuelAnimationDict = 'amb@world_human_security_shine_torch@male@base'
Config.RefuelAnimationName = 'base'
Config.RefuelAnimationFlag = 1
Config.RefuelAnimationScenario = 'WORLD_HUMAN_VEHICLE_MECHANIC'
Config.FullTankSnapTolerance = 0.25
Config.NativeFuelDriveFloorPercent = 10.0
Config.NativeFuelDriveFloorAbsolute = 0.0
Config.UseNativeElectricVehicleDetection = true
Config.ConsumptionTickMs = 1000
Config.BaseUsagePerSecond = 0.18
Config.IdleUsageMultiplier = 0.1
Config.IdleSpeedThresholdKmh = 1.0
Config.SpeedUsageMultiplier = 0.35
Config.SyncTolerance = 0.2
Config.HudUpdateMs = 150
Config.HudLowFuelPercent = 15.0
Config.HudCriticalFuelPercent = 7.0

Config.DisabledVehicleClasses = {
    [13] = true,
    [14] = true,
    [15] = true,
    [16] = true,
    [21] = true
}

Config.ClassUsageMultiplier = {
    [0] = 1.0,
    [1] = 1.0,
    [2] = 1.05,
    [3] = 0.95,
    [4] = 1.1,
    [5] = 1.15,
    [6] = 1.0,
    [7] = 1.3,
    [8] = 0.75,
    [9] = 1.35,
    [10] = 1.6,
    [11] = 1.0,
    [12] = 1.25,
    [17] = 0.9,
    [18] = 0.85,
    [19] = 1.8,
    [20] = 1.45
}

Config.PumpModels = {
    `prop_gas_pump_1a`,
    `prop_gas_pump_1b`,
    `prop_gas_pump_1c`,
    `prop_gas_pump_1d`,
    `prop_gas_pump_old2`,
    `prop_gas_pump_old3`,
    `prop_vintage_pump`
}

Config.EVChargerLocations = {
    vector3(-142.43, 6277.65, 31.48),
    vector3(-137.56, 6282.52, 31.49),
    vector3(-132.87, 6287.21, 31.49),
    vector3(-122.27, 6278.99, 31.46),
    vector3(-124.75, 6276.51, 31.44),
    vector3(-126.98, 6274.27, 31.46),
    vector3(-129.34, 6271.90, 31.44),
    vector3(-131.70, 6269.54, 31.44),
    vector3(-134.33, 6266.92, 31.44),
    vector3(196.32, 6633.04, 31.52),
    vector3(199.87, 6632.08, 31.50),
    vector3(286.92, -1275.47, 29.29),
    vector3(286.95, -1270.01, 29.29),
    vector3(639.87, 260.17, 103.30),
    vector3(-2076.04, -331.73, 13.17),
    vector3(-721.09, -913.11, 19.01),
    vector3(-1788.44, 814.27, 138.50),
}

Config.ElectricVehicleModels = {
    `tr22`,
    `p90d`,
    `models`,
    `tmodel`,
    `teslax`,
    `teslapd`
}