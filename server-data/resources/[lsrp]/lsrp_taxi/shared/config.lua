Config = Config or {}

Config.JobId = 'taxi_player'
Config.InteractionKey = 38
Config.DrawDistance = 30.0
Config.InteractionDistance = 2.5
Config.PickupRadius = 18.0
Config.DestinationRadius = 24.0
Config.DriverPassengerRadius = 25.0
Config.VehicleModel = 'taxi'
Config.VehiclePlatePrefix = 'CAB'
Config.BaseFare = 90
Config.DistanceFareMultiplier = 0.28
Config.MinimumPayout = 125
Config.MaximumPayout = 650

Config.JobDefinition = {
	id = 'taxi_player',
	label = 'Downtown Cab Live',
	description = 'Pick up real player fares booked through the city phone dispatch app.',
	public = true,
	tags = { 'civilian', 'driving', 'service' },
	jobCenter = {
		subtitle = 'Live passenger dispatch',
		requirements = {
			'Visit the depot to clock in and collect a company taxi.',
			'Stay on duty to appear on the dispatch board.',
			'Claim live player rides from the Taxi phone app.'
		},
		sortOrder = 11,
		accent = '#7bd6a3'
	},
	payroll = {
		enabled = true,
		intervalSeconds = 900,
		reason = 'taxi_player_payroll'
	},
	grades = {
		{
			id = 'driver',
			label = 'Taxi Driver',
			pay = 160,
			payIntervalSeconds = 900,
			permissions = {
				'taxi_player.duty.toggle',
				'taxi_player.vehicle.spawn',
				'taxi_player.dispatch.claim',
				'taxi_player.dispatch.complete'
			}
		},
		{
			id = 'senior_driver',
			label = 'Senior Driver',
			pay = 200,
			payIntervalSeconds = 900,
			permissions = {
				'taxi_player.*'
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