Config = Config or {}

Config.JobId = 'tow_operator'
Config.InteractionKey = 38
Config.ImpoundCommand = 'impound'
Config.ImpoundParkingZone = 'Tow recovery unrepaired'
Config.ImpoundRange = 2.0
Config.HookCommand = '+lsrptowhook'
Config.UnhookCommand = '-lsrptowhook'
Config.HookKeyDefault = 'G'
Config.DrawDistance = 30.0
Config.InteractionDistance = 2.5
Config.VehicleModel = 'towtruck2'
Config.VehiclePlatePrefix = 'TOW'
Config.AttachSearchRadius = 11.0
Config.AttachRearMinDistance = 1.5
Config.AttachRearMaxDistance = 9.5
Config.AttachMaxSideOffset = 3.6
Config.AttachMaxHeightOffset = 2.8
Config.AttachOffset = {
	x = 0.0,
	y = -2.8,
	z = 1.05
}

Config.JobDefinition = {
	id = 'tow_operator',
	label = 'LS Recovery & Tow',
	description = 'Operate a company tow truck, clear disabled vehicles, and keep the roads moving.',
	public = true,
	tags = { 'civilian', 'driving', 'service' },
	jobCenter = {
		subtitle = 'Company tow truck operator',
		requirements = {
			'Apply at the job center, then visit the tow yard to clock in.',
			'Use the yard bay to collect a company tow truck.',
			'Attach disabled or abandoned vehicles and clear them safely.'
		},
		sortOrder = 12,
		accent = '#f29f58'
	},
	payroll = {
		enabled = true,
		intervalSeconds = 900,
		reason = 'tow_operator_payroll'
	},
	grades = {
		{
			id = 'operator',
			label = 'Tow Operator',
			pay = 190,
			payIntervalSeconds = 900,
			permissions = {
				'tow_operator.duty.toggle',
				'tow_operator.vehicle.spawn',
				'tow_operator.vehicle.tow',
				'tow_operator.vehicle.impound'
			}
		},
		{
			id = 'senior_operator',
			label = 'Senior Tow Operator',
			pay = 235,
			payIntervalSeconds = 900,
			permissions = {
				'tow_operator.*'
			}
		}
	}
}

Config.Depots = {
	{
		id = 'davis_yard',
		label = 'LS Recovery Yard',
		blip = {
			enabled = true,
			sprite = 68,
			scale = 0.85,
			color = 17,
			label = 'Tow Yard'
		},
		dutyCoords = vector3(409.83, -1623.31, 29.29),
		vehicleSpawn = {
			coords = vector3(401.15, -1637.09, 29.29),
			heading = 229.74
		},
		vehicleReturn = vector3(397.02, -1644.29, 29.29)
	}
}