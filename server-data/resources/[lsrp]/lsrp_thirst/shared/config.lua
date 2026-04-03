Config = Config or {}

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