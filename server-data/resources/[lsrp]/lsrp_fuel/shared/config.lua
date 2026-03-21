Config = Config or {}

Config.DefaultTankCapacity = 65.0
Config.MinTankCapacity = 5.0
Config.MaxTankCapacity = 200.0
Config.EmptyFuelThreshold = 0.1
Config.RefuelControl = 38
Config.PumpScanRadius = 5.0
Config.PumpInteractDistance = 2.75
Config.VehicleSearchRadius = 4.0
Config.PumpVehicleDistance = 6.0
Config.RefuelDurationMsPerUnit = 80
Config.RefuelCostPerUnit = 2
Config.ConsumptionTickMs = 1000
Config.BaseUsagePerSecond = 0.18
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