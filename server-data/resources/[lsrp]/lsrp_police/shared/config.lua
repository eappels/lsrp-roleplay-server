Config = Config or {}

Config.JobId = 'police_officer'
Config.InteractionKey = 38
Config.ImpoundCommand = 'impound'
Config.ImpoundParkingZone = 'Tow recovery unrepaired'
Config.ImpoundRange = 3.5
Config.DrawDistance = 30.0
Config.InteractionDistance = 2.5
Config.VehicleModel = 'police3'
Config.VehiclePlatePrefix = 'LSPD'
Config.VehicleColors = {
	primary = 111,
	secondary = 111
}

Config.JobDefinition = {
	id = 'police_officer',
	label = 'Los Santos Police Department',
	description = 'Patrol the city, respond to incidents, and keep the peace for Los Santos.',
	public = false,
	tags = { 'government', 'emergency', 'law' },
	payroll = {
		enabled = true,
		intervalSeconds = 900,
		reason = 'police_officer_payroll'
	},
	grades = {
		{
			id = 'officer',
			label = 'Police Officer',
			pay = 260,
			payIntervalSeconds = 900,
			permissions = {
				'police_officer.duty.toggle',
				'police_officer.vehicle.spawn',
				'police_officer.vehicle.impound'
			}
		},
		{
			id = 'sergeant',
			label = 'Police Sergeant',
			pay = 320,
			payIntervalSeconds = 900,
			permissions = {
				'police_officer.duty.toggle',
				'police_officer.vehicle.spawn',
				'police_officer.vehicle.impound',
				'police_officer.supervise'
			}
		},
		{
			id = 'lieutenant',
			label = 'Police Lieutenant',
			pay = 390,
			payIntervalSeconds = 900,
			permissions = {
				'police_officer.*'
			}
		}
	}
}

Config.Stations = {
	{
		id = 'mission_row',
		label = 'Mission Row Police Department',
		blip = {
			enabled = true,
			sprite = 60,
			scale = 0.82,
			color = 38,
			label = 'Mission Row PD'
		},
		dutyCoords = vector3(441.15, -981.89, 30.69),
		vehicleSpawn = {
			coords = vector3(454.29, -1017.42, 28.42),
			heading = 90.0
		},
		vehicleReturn = vector3(462.33, -1019.36, 28.1)
	}
}