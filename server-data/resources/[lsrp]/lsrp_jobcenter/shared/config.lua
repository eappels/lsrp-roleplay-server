Config = Config or {}

Config.InteractionKey = 38
Config.DrawDistance = 22.0
Config.InteractionDistance = 1.8
Config.AutoCloseDistance = 6.0
Config.OpenPrompt = 'Press ~INPUT_CONTEXT~ to browse civilian jobs'

Config.Marker = {
	enabled = true,
	type = 27,
	scale = { x = 0.38, y = 0.38, z = 0.38 },
	color = { r = 242, g = 193, b = 78, a = 190 },
	bobUpAndDown = false,
	rotate = false
}

Config.JobCenters = {
	{
		id = 'city_hall',
		name = 'City Hall Job Center',
		subtitle = 'Apply for licensed civilian work',
		coords = vector3(-545.52, -204.63, 38.22),
		blip = {
			enabled = true,
			sprite = 407,
			scale = 0.78,
			color = 46,
			label = 'Job Center'
		}
	}
}