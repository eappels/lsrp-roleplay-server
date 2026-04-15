Config = Config or {}

Config.Debug = false
Config.InteractionKey = 38
Config.DrawDistance = 30.0
Config.InteractionDistance = 2.0

Config.JobId = 'ems_responder'

Config.Stages = {
	COLLAPSED = 'collapsed',
	STABILIZED = 'stabilized',
	ESCORTED = 'escorted',
	IN_TRANSPORT = 'in_transport',
	HOSPITAL_ESCORT = 'hospital_escort',
	IN_TREATMENT = 'in_treatment',
	READY_FOR_DISCHARGE = 'ready_for_discharge'
}

Config.Markers = {
	duty = {
		coords = vector3(304.87, -601.03, 43.26),
		label = 'EMS Duty Locker'
	},
	checkIn = {
		coords = vector3(308.17, -595.20, 43.26),
		label = 'Patient Check-In'
	},
	garage = {
		coords = vector3(294.36, -611.32, 43.35),
		label = 'Ambulance Garage',
		parkingZone = 'Pillbox Ambulance Garage'
	}
}

Config.Blip = {
	enabled = true,
	coords = vector3(304.87, -601.03, 43.26),
	sprite = 61,
	color = 1,
	scale = 0.82,
	label = 'Pillbox Medical Services'
}

Config.Revive = {
	range = 2.5,
	durationMs = 5000,
	healthOnRevive = 160,
	label = 'revive the patient'
}

Config.Stabilize = {
	range = 2.5,
	durationMs = 3500,
	collapsedDurationMs = 25000,
	minHealthThreshold = 175,
	healthAfterStabilize = 175,
	label = 'stabilize the patient',
	collapsedLabel = 'check the patient\'s vitals',
	collapsedScenario = 'CODE_HUMAN_MEDIC_TEND_TO_DEAD'
}

Config.Transport = {
	range = 3.0,
	vehicleRange = 10.0,
	escortDurationMs = 1800,
	escortLabel = 'escort the patient',
	releaseEscortLabel = 'release the patient',
	escortAttachBone = 11816,
	escortAttachOffset = vector3(0.54, 0.44, 0.0),
	escortMaxDistance = 22.0,
	preferredPatientSeats = { 2, 1 },
	loadPointOffset = vector3(0.0, -4.1, 0.0),
	loadPointRadius = 3.25,
	unloadDistance = 5.0,
	loadZoneHalfWidth = 2.2,
	loadZoneRearMin = 1.0,
	loadZoneRearMax = 6.0,
	civilianDisallowedVehicleClasses = { 8, 13, 14, 15, 16, 21 },
	allowedVehicleModels = {
		'ambulance'
	},
	loadLabel = 'put the patient into the ambulance',
	hospitalLabel = 'grab the patient from the vehicle',
	healthAfterHospital = 200,
	dropoff = {
		coords = vector3(295.87, -584.56, 43.19),
		radius = 8.0,
		marker = {
			type = 1,
			scale = vector3(3.0, 3.0, 0.9),
			color = { r = 214, g = 69, b = 69, a = 110 }
		}
	}
}

Config.Treatment = {
	checkInRange = 2.5,
	releaseRange = 3.5,
	checkInLabel = 'escort the patient to check-in',
	selfCheckInLabel = 'check yourself in for treatment',
	durationMs = 30000,
	healthAfterTreatment = 200,
	hudLabel = 'Treatment',
	dischargePrompt = 'Press ~INPUT_CONTEXT~ to stand up',
	billing = {
		enabled = true,
		amount = 350,
		reason = 'ems_treatment'
	},
	bed = {
		coords = vector3(353.65, -584.50, 44.05),
		poseOffset = vector3(0.0, 0.0, 0.25),
		animPoseOffset = vector3(0.0, 0.0, 0.7),
		surfaceZAdjust = -0.02,
		heading = 160.0,
		exitOffset = vector3(1.15, 0.0, 0.0),
		poseMode = 'anim',
		objectSearchRadius = 2.5,
		objectModels = {
			'jhy_med_bed3',
			'jhy_med_bed4',
			'jhy_med_bed5',
			'jhy_med_bedempty',
			'jhy_med_er_bed',
			'jhy_med_er_bed2',
			'jhy_med_icu_bed',
			'jhy_med_surgery_bed',
			'v_med_wheelbed'
		},
		scenarioName = 'WORLD_HUMAN_SUNBATHE_BACK',
		animDict = 'dead',
		animName = 'dead_a',
		animFlag = 1
	}
}

Config.ActionAnimation = {
	animDict = 'mini@cpr@char_a@cpr_str',
	animName = 'cpr_pumpchest',
	flag = 49
}

Config.JobDefinition = {
	id = Config.JobId,
	label = 'Los Santos Medical Services',
	description = 'Emergency medical response, triage, and hospital support.',
	public = false,
	allowDuty = true,
	defaultGradeId = 'emt',
	jobCenter = {
		subtitle = 'Emergency services role',
		sortOrder = 40,
		accent = '#d64545'
	},
	payroll = {
		enabled = true,
		intervalSeconds = 900,
		reason = 'ems_payroll'
	},
	grades = {
		{
			id = 'emt',
			label = 'EMT',
			pay = 145,
			permissions = {
				'ems.triage.view'
			}
		},
		{
			id = 'paramedic',
			label = 'Paramedic',
			pay = 180,
			permissions = {
				'ems.triage.view',
				'ems.response.dispatch'
			}
		},
		{
			id = 'chief',
			label = 'Chief Physician',
			pay = 240,
			permissions = {
				'ems.*'
			}
		}
	}
}