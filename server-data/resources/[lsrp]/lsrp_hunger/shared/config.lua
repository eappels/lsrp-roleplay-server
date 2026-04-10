Config = Config or {}

Config.Hunger = {
	enabled = true,
	maxHunger = 100,
	defaultHunger = 100,
	decayIntervalMs = 72000,
	decayAmount = 1,
	lowThreshold = 25,
	criticalThreshold = 10,
	starvationDamageIntervalMs = 30000,
	starvationDamage = 5,
	statusCommand = 'hunger'
}

Config.Thirst = {
	enabled = true,
	maxThirst = 100,
	defaultThirst = 100,
	decayIntervalMs = 36000,
	decayAmount = 1,
	lowThreshold = 25,
	criticalThreshold = 10,
	dehydrationDamageIntervalMs = 30000,
	dehydrationDamage = 5,
	statusCommand = 'thirst'
}