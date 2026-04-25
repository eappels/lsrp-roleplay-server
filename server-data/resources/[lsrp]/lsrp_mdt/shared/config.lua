Config = Config or {}

Config.Debug = false
Config.Command = 'mdt'
Config.CloseCommand = 'mdt_close'
Config.PreviewCommand = 'mdt_preview'
Config.AdminAce = 'lsrp.mdt.admin'

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
	'Name and state ID lookup now merges live players with stored MDT profiles.',
	'Only on-duty police can add intel notes or manage tags on a profile.',
	'Police and EMS can open the MDT, and the roster only shows police currently on duty.'
}

Config.Shortcuts = {
	{ id = 'person_lookup', label = 'Profile Search', description = 'Search by player name or exact state ID', event = 'personLookup' },
	{ id = 'profile_select', label = 'Profile View', description = 'Open a selected profile to review tags and intel', event = 'selectProfile' },
	{ id = 'intel_note', label = 'Intel Notes', description = 'On-duty police can add intel entries to a profile', event = 'addIntel' },
	{ id = 'police_roster', label = 'Police Roster', description = 'Review which police units are currently on duty', event = 'refreshRoster' }
}