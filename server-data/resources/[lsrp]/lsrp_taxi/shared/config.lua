Config = Config or {}

Config.JobId = 'taxi'
Config.InteractionKey = 38
Config.DrawDistance = 30.0
Config.InteractionDistance = 2.5
Config.PickupRadius = 18.0
Config.DestinationRadius = 24.0
Config.NextFareDelayMinSeconds = 60
Config.NextFareDelayMaxSeconds = 600
Config.VehicleModel = 'taxi'
Config.VehiclePlatePrefix = 'TAXI'
Config.PassengerWaitScenario = 'WORLD_HUMAN_STAND_IMPATIENT'
Config.PassengerCleanupDelayMs = 12000
Config.PassengerModels = {
	'a_f_m_bevhills_01',
	'a_f_y_business_01',
	'a_m_m_business_01',
	'a_m_y_business_02',
	'a_m_y_genstreet_01',
	'a_f_y_tourist_01'
}

Config.JobDefinition = {
	id = 'taxi',
	label = 'Downtown Cab',
	description = 'Drive city fares, stay on duty, and earn payroll plus fare payouts while working the cab line.',
	public = true,
	tags = { 'civilian', 'driving', 'service' },
	jobCenter = {
		subtitle = 'Metered passenger transport',
		requirements = {
			'Visit the depot to clock in and collect a cab.',
			'Stay on duty to receive payroll.',
			'Keep your company taxi out to receive dispatch jobs automatically.'
		},
		sortOrder = 10,
		accent = '#d9b44a'
	},
	payroll = {
		enabled = true,
		intervalSeconds = 900,
		reason = 'taxi_payroll'
	},
	grades = {
		{
			id = 'driver',
			label = 'Taxi Driver',
			pay = 140,
			payIntervalSeconds = 900,
			permissions = {
				'taxi.duty.toggle',
				'taxi.vehicle.spawn',
				'taxi.fare.start',
				'taxi.fare.complete'
			}
		},
		{
			id = 'senior_driver',
			label = 'Senior Driver',
			pay = 180,
			payIntervalSeconds = 900,
			permissions = {
				'taxi.*'
			}
		}
	}
}

Config.Depots = {
	{
		id = 'mission_row',
		label = 'Downtown Cab Depot',
		blip = {
			enabled = true,
			sprite = 198,
			scale = 0.82,
			color = 46,
			label = 'Taxi Depot'
		},
		dutyCoords = vector3(895.98, -179.62, 74.7),
		vehicleSpawn = {
			coords = vector3(907.42, -176.23, 74.17),
			heading = 238.02
		},
		vehicleReturn = vector3(909.37, -166.11, 74.25)
	}
}

Config.PickupLocations = {
	{ id = 'legion_square', label = 'Legion Square', coords = vector3(222.06, -865.31, 30.14), heading = 248.0 },
	{ id = 'pillbox', label = 'Pillbox Hill', coords = vector3(289.93, -588.67, 43.16), heading = 339.0 },
	{ id = 'mirror_park', label = 'Mirror Park', coords = vector3(1183.4, -451.94, 66.66), heading = 81.0 },
	{ id = 'vespucci', label = 'Vespucci Canals', coords = vector3(-1048.67, -790.11, 18.91), heading = 219.0 },
	{ id = 'del_perro', label = 'Del Perro Beach', coords = vector3(-1358.58, -1048.06, 4.35), heading = 32.0 },
	{ id = 'airport', label = 'Los Santos International', coords = vector3(-1034.37, -2731.85, 20.17), heading = 241.0 }
}

Config.Destinations = {
	{ id = 'pillbox', label = 'Pillbox Hill', coords = vector3(289.41, -584.03, 43.19), payout = 175 },
	{ id = 'vespucci', label = 'Vespucci Canals', coords = vector3(-1027.44, -877.55, 5.04), payout = 235 },
	{ id = 'del_perro', label = 'Del Perro Beach', coords = vector3(-1468.12, -654.44, 29.58), payout = 260 },
	{ id = 'mirror_park', label = 'Mirror Park', coords = vector3(1212.38, -470.11, 66.21), payout = 225 },
	{ id = 'vinewood', label = 'Vinewood Plaza', coords = vector3(648.18, 208.72, 97.6), payout = 200 },
	{ id = 'lsia', label = 'Los Santos International', coords = vector3(-1037.81, -2733.72, 20.17), payout = 320 }
}