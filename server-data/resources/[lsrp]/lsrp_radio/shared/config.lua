Config = Config or {}

Config.Debug = false

Config.ItemName = 'radio'
Config.Command = 'radio'
Config.VolumeCommand = 'radiovol'
Config.MinChannel = 1
Config.MaxChannel = 999
Config.AccessRefreshMs = 15000
Config.PromptTitle = 'Enter radio channel (0 to leave)'

Config.UsableItem = {
	label = 'Use Radio',
	mode = 'none',
	durationMs = 750,
	consumeAmount = 0,
	requireOnFoot = false
}

Config.RestrictedChannels = {
	{
		id = 'police_dispatch',
		label = 'LSPD Dispatch',
		channels = { 1, 2, 3, 4 },
		jobs = { 'police_officer' },
		requireDuty = true
	},
	{
		id = 'ems_dispatch',
		label = 'EMS Dispatch',
		channels = { 5, 6 },
		jobs = { 'ems_responder' },
		requireDuty = true
	},
	{
		id = 'emergency_command',
		label = 'Emergency Command',
		channels = { 9 },
		jobs = { 'police_officer', 'ems_responder' },
		requireDuty = true
	}
}