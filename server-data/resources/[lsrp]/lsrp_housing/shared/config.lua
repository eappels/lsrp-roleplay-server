Config = Config or {}

Config.EnableNui = true
Config.CombineCatalogAndKiosk = true

Config.InteractControl = 38
Config.PromptDistance = 1.6
Config.MarkerDistance = 15.0
Config.MarkerType = 1
Config.MarkerScale = { x = 0.35, y = 0.35, z = 0.2 }
Config.MarkerColor = { r = 88, g = 173, b = 255, a = 160 }
Config.InteriorExitFallbackRadius = 12.0
Config.Blip = {
	enabled = true,
	sprite = 40,
	color = 2,
	scale = 0.8,
	shortRange = true,
	label = 'Alta Apartments'
}

Config.RentPeriodDays = 30
Config.EvictionGracePeriodSeconds = 15 * 60
Config.OverdueScanIntervalMs = 60 * 1000
Config.PendingNotificationCheckMs = 5 * 1000
Config.BucketOffset = 1500

Config.Commands = {
	keypad = 'housing',
	catalog = 'housingcatalog',
	kiosk = 'housingkiosk',
	leave = 'leaveapartment',
	available = 'housingavailable',
	owned = 'housingowned',
	enter = 'houseenter',
	rent = 'houserent',
	help = 'housinghelp'
}

Config.Text = {
	entryPrompt = 'Press ~INPUT_CONTEXT~ to access the apartment keypad',
	catalogPrompt = 'Press ~INPUT_CONTEXT~ to manage apartments',
	kioskPrompt = 'Press ~INPUT_CONTEXT~ to manage rent',
	exitPrompt = 'Press ~INPUT_CONTEXT~ to leave your apartment',
	exitFallbackPrompt = 'Press ~INPUT_CONTEXT~ to leave the apartment',
	storagePrompt = 'Press ~INPUT_CONTEXT~ to open apartment storage'
}

Config.DefaultApartments = {
	{ apartment_number = '1001', location_index = 1, price = 5000 },
	{ apartment_number = '1002', location_index = 1, price = 5000 },
	{ apartment_number = '1003', location_index = 1, price = 5000 },
	{ apartment_number = '1004', location_index = 1, price = 5000 },
	{ apartment_number = '1005', location_index = 1, price = 5000 },
	{ apartment_number = '1006', location_index = 1, price = 5000 },
	{ apartment_number = '1007', location_index = 1, price = 5000 },
	{ apartment_number = '1008', location_index = 1, price = 5000 },
	{ apartment_number = '1009', location_index = 1, price = 5000 },
	{ apartment_number = '1010', location_index = 1, price = 5000 }
}

Config.Locations = {
	{
		label = 'Alta Apartments',
		entry = { x = -263.59, y = -959.94, z = 31.22, w = 68.0 },
		catalog = { x = -260.39, y = -965.37, z = 31.22, w = 68.0 },
		exteriorSpawn = { x = -263.59, y = -959.94, z = 31.22, w = 248.0 },
		interiorSpawn = { x = 266.08, y = -1007.52, z = -101.01, w = 356.0 },
		interiorExit = { x = 266.08, y = -1007.51, z = -101.01, w = 182.0 },
		interiorStorage = {
			x = 260.02,
			y = -1004.05,
			z = -99.01,
			w = 0.0,
			label = 'Apartment Storage',
			slots = 40,
			maxWeight = 75000
		}
	}
}