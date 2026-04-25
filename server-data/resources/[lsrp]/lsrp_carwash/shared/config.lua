Config = Config or {}

Config.OpenKey = 38 -- E
Config.PromptDistance = 3.0
Config.MarkerDistance = 18.0
Config.AutoCloseDistance = 8.0
Config.WashDurationMs = 3500
Config.WashPrice = 50
Config.PromptText = 'Press ~INPUT_CONTEXT~ to use the carwash'

Config.Locations = {
	{
		id = 'downtown_carwash',
		label = 'Downtown Carwash',
		coords = vector3(24.65, -1391.77, 28.89),
		heading = 88.23,
		marker = {
			enabled = true,
			type = 36,
			scale = vector3(1.0, 1.0, 1.0),
			color = { r = 86, g = 195, b = 138, a = 190 }
		},
		blip = {
			enabled = true,
			sprite = 100,
			color = 2,
			scale = 0.8,
			label = 'Carwash'
		}
	}
}