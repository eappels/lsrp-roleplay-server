Config = Config or {}

Config.VehicleBehaviour = {
	enabled = true,
	ignition = {
		enabled = true,
		commandName = 'ignition',
		key = 'LMENU',
		modifierKey = 'LCONTROL',
		driverSeatOnly = true,
		notify = true
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
