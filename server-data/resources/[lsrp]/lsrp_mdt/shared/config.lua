Config = Config or {}

Config.Debug = false
Config.Command = 'mdt'
Config.CloseCommand = 'mdt_close'
Config.PreviewCommand = 'mdt_preview'

Config.AccessJobs = {
	police_officer = {
		label = 'LSPD Access',
		requireDuty = true
	},
	ems_responder = {
		label = 'EMS Access',
		requireDuty = true
	}
}

Config.DefaultNotices = {
	'Current pass includes online person lookup, exact plate lookup, and an on-duty unit roster.',
	'BOLOs and incident reports are still placeholders until persistence is added.',
	'Current access is limited to configured duty jobs.'
}

Config.Shortcuts = {
	{ id = 'person_lookup', label = 'Person Lookup', description = 'Search online people by name or exact state ID', event = 'personLookup' },
	{ id = 'vehicle_lookup', label = 'Vehicle Lookup', description = 'Search exact vehicle plate ownership and status', event = 'vehicleLookup' },
	{ id = 'bolo_board', label = 'BOLO Board', description = 'Placeholder board until persistent alerts are added', event = 'boloBoard' },
	{ id = 'incident_log', label = 'Incident Log', description = 'Placeholder log until reports are implemented', event = 'incidentLog' }
}