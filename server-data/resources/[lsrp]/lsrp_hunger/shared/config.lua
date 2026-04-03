Config = Config or {}

Config.Hunger = {
	enabled = true,
	maxHunger = 100,
	defaultHunger = 100,
	decayIntervalMs = 180000,
	decayAmount = 1,
	lowThreshold = 25,
	criticalThreshold = 10,
	starvationDamageIntervalMs = 30000,
	starvationDamage = 5,
	statusCommand = 'hunger'
}