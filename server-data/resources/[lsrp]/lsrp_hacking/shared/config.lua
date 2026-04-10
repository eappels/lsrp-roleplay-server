Config = Config or {}

Config.Debug = false
Config.AtmUseDistance = 2.4
Config.AtmScanRadius = 5.0
Config.ValidationDistance = 3.0
Config.ExteriorOnlyAtms = false
Config.CooldownSeconds = 600
Config.HackPuzzle = {
	rounds = 2,
	timeLimitSeconds = 45,
	roundNodeCounts = { 3, 4, 5 }
}
Config.Vendor = {
	enabled = true,
	model = 'g_m_y_mexgoon_01',
	coords = vector4(88.80, -1961.16, 20.75, 229.90),
	interactDistance = 2.0,
	drawDistance = 18.0,
	requiredTalks = 3,
	price = 25000,
	itemName = 'WEAPON_HACKINGDEVICE',
	itemLabel = 'Hacking Device',
	prompt = 'Press ~INPUT_CONTEXT~ to talk to the Vago',
	dialogue = {
		'You do not walk up to me and ask for toys on the first hello. Come back when you are serious.',
		'Easy, amigo. I need to know you are not wearing a wire. Talk again if you still want in.',
		'Alright. You kept coming back. Bring LS$25000 in cash and the device is yours.'
	}
}
Config.Reward = {
	min = 1000,
	max = 8500,
	reason = 'atm_hack'
}
Config.AtmModels = {
	`prop_atm_01`,
	`prop_atm_02`,
	`prop_atm_03`,
	`prop_fleeca_atm`
}