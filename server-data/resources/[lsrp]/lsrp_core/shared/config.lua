-- LSRP Core - Shared Configuration
--
-- All values in lsrpConfig are available to both client and server scripts of
-- any resource that lists lsrp_core as a dependency and imports this file.

lsrpConfig = {}

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

lsrpConfig.pedEditorAutoRestoreEnabled = true
-- Keep this nil to restore the most recently saved outfit.
lsrpConfig.pedEditorAutoRestoreSlot = nil
lsrpConfig.pedEditorAutoRestoreDelayMs = 300

-- Vehicle editor camera distance multiplier.
-- 1.0 = original distance, 0.5 = half distance, values > 1 move farther away.
lsrpConfig.vehicleEditorCameraDistanceMultiplier = 0.45

