-- LSRP Core - Shared Configuration
--
-- All values in lsrpConfig are available to both client and server scripts of
-- any resource that lists lsrp_core as a dependency and imports this file.

lsrpConfig = {}

-- When false, only players with the maintenance bypass ACE may connect.
lsrpConfig.allowPlayerConnections = true
lsrpConfig.connectionClosedBypassAce = 'lsrp.core.connect_when_closed'
lsrpConfig.enableConnectionQueue = true
lsrpConfig.connectionQueueUpdateIntervalMs = 3000

-- Default ped model used when no saved outfit is found.
lsrpConfig.defaultMalePedModel = 'mp_m_freemode_01'
lsrpConfig.defaultFemalePedModel = 'mp_f_freemode_01'

-- World coordinates where a new (or position-less) player spawns.
lsrpConfig.defaultSpawnHeading = 0.0
lsrpConfig.playerPositionSaveIntervalMs = 30000
-- Minimum movement (in meters) before a periodic save is queued.
lsrpConfig.playerPositionSaveMinDistance = 1.5
-- Minimum heading delta (in degrees) before a periodic save is queued.
lsrpConfig.playerPositionSaveMinHeadingDelta = 7.5
-- Force a save after this much time even if movement thresholds are not met. Set to 0 to disable forced saves.
lsrpConfig.playerPositionForceSaveIntervalMs = 180000

lsrpConfig.compassEnabled = true
lsrpConfig.compassUseCameraHeading = true
lsrpConfig.compassShowDegrees = true
lsrpConfig.compassShowDirectionText = true

lsrpConfig.coordinateHudEnabled = true
lsrpConfig.coordinateHudShowHeading = true
lsrpConfig.coordinateHudShowStreet = true
lsrpConfig.coordinateHudUpdateIntervalMs = 200
lsrpConfig.hungerHudEnabled = true
lsrpConfig.hungerHudUpdateIntervalMs = 500

-- Shared widget layout definitions for lsrp_hud.
-- Future HUD widgets should prefer adding layout values here rather than
-- hardcoding screen positions in resource-local CSS.
lsrpConfig.hudWidgets = {
	needsShell = {
		left = '26.125rem',
		bottom = '0.95rem',
		width = 'min(16rem, 24vw)',
		transform = 'none',
		mobileLeft = '1rem',
		mobileRight = 'auto',
		mobileBottom = '5.75rem',
		mobileWidth = 'min(16rem, calc(100vw - 2rem))',
		mobileTransform = 'none'
	},
	fuelShell = {
		left = '50%',
		bottom = '1rem',
		width = 'min(16rem, calc(100vw - 2rem))',
		transform = 'translateX(-50%)',
		mobileLeft = '50%',
		mobileRight = 'auto',
		mobileBottom = '1rem',
		mobileWidth = 'min(16rem, calc(100vw - 2rem))',
		mobileTransform = 'translateX(-50%)'
	}
}

lsrpConfig.pedEditorAutoRestoreEnabled = true
-- Keep this nil to restore the most recently saved outfit.
lsrpConfig.pedEditorAutoRestoreSlot = nil
lsrpConfig.pedEditorAutoRestoreDelayMs = 300

-- Vehicle editor camera distance multiplier.
-- 1.0 = original distance, 0.5 = half distance, values > 1 move farther away.
lsrpConfig.vehicleEditorCameraDistanceMultiplier = 0.45

