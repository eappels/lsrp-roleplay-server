Config = Config or {}

Config.VehicleBehaviour = {
	enabled = true,
	doorControl = {
		enabled = true,
		commandName = 'vehdoors',
		key = 'F2',
		searchRadius = 6.0,
		notify = true
	},
	ignition = {
		enabled = true,
		commandName = 'ignition',
		key = 'LMENU',
		modifierKey = 'LCONTROL',
		driverSeatOnly = true,
		notify = true
	},
	emergencyLights = {
		enabled = true,
		commandName = 'emlights',
		key = 'Q',
		-- Emergency vehicle state flow:
		-- Off -> Q = lights only, E = lights + sirens
		-- Lights only -> Q = off, E = lights + sirens
		-- Lights + sirens -> Q = lights only, E = off
		driverSeatOnly = true,
		notify = false
	},
	keys = {
		enabled = true,
		lockCommandName = 'vehiclelock',
		lockKey = 'X',
		giveCommandName = 'givekey',
		preventForcedEntryWithKey = true,
		forcedEntryHandleTryMs = 750,
		forcedEntryRetryDelayMs = 150,
		forcedEntryDoorRangePadding = 0.85,
		lockSearchRadius = 10.0,
		cacheMs = 6000,
		lockSoundEnabled = true,
		lockSoundMode = 'entity',
		lockSoundBroadcastRange = 45.0,
		frontendSoundSet = 'HUD_FRONTEND_DEFAULT_SOUNDSET',
		frontendLockSoundName = 'NAV_UP_DOWN',
		frontendUnlockSoundName = 'NAV_UP_DOWN',
		unlockUseDoorOpenSound = false,
		lockSoundSet = 'PI_Menu_Sounds',
		lockSoundName = 'Remote_Control_Close',
		unlockSoundName = 'Remote_Control_Open',
		notify = true
	}
}
