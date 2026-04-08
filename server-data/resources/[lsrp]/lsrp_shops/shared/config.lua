Config = Config or {}

Config.InteractionKey = 38 -- E
Config.OpenPrompt = 'Press ~INPUT_CONTEXT~ to browse 24/7 goods'
Config.AutoCloseDistance = 8.0
Config.DrawDistance = 20.0

Config.Marker = {
	enabled = true,
	type = 27,
	scale = vector3(0.45, 0.45, 0.45),
	color = { r = 91, g = 197, b = 255, a = 185 },
	bobUpAndDown = false,
	rotate = true
}

Config.DefaultBlip = {
	enabled = true,
	sprite = 52,
	color = 2,
	scale = 0.75,
	label = '24/7 Convenience Store'
}

Config.Catalogs = {
	essentials = {
		id = 'essentials',
		label = '24/7 Essentials',
		items = {
			{
				name = 'burger',
				label = 'Microwave Burger',
				price = 8,
				maxQuantity = 5,
				description = 'Cheap, fast, and hot enough to count as food.'
			},
			{
				name = 'cola',
				label = 'Cola',
				price = 5,
				maxQuantity = 6,
				description = 'Cold sugar in a can.'
			},
			{
				name = 'phone',
				label = 'Phone',
				price = 999,
				maxQuantity = 1,
				uniquePerPlayer = true,
				description = 'A prepaid handset for calls, contacts, and messages.'
			},
			{
				name = 'bandage',
				label = 'Bandage',
				price = 45,
				maxQuantity = 3,
				description = 'Basic first aid for minor injuries.'
			},
			{
				name = 'gascan',
				label = 'Gas Can',
				price = 180,
				maxQuantity = 1,
				description = 'Portable fuel for when the nearest pump is too far away.'
			},
			{
				name = 'repairkit',
				label = 'Repair Kit',
				price = 275,
				maxQuantity = 1,
				description = 'A compact repair pack for quick roadside fixes.'
			},
			{
				name = 'lockpick',
				label = 'Lockpick',
				price = 120,
				maxQuantity = 2,
				description = 'A risky tool sold with no questions asked.'
			}
		}
	}
}

Config.Stores = {
	{
		id = 'downtown_vinewood',
		name = '24/7 Supermarket',
		subtitle = 'Snacks, first aid, and quick supplies.',
		catalogId = 'essentials',
		interaction = vector3(25.74, -1345.62, 29.49),
		interactionRadius = 1.8
	},
	{
		id = 'innocence_blvd',
		name = '24/7 Supermarket',
		subtitle = 'Snacks, first aid, and quick supplies.',
		catalogId = 'essentials',
		interaction = vector3(-47.25, -1758.73, 29.42),
		interactionRadius = 1.8
	},
	{
		id = 'clinton_ave',
		name = '24/7 Supermarket',
		subtitle = 'Snacks, first aid, and quick supplies.',
		catalogId = 'essentials',
		interaction = vector3(373.13, 326.29, 103.57),
		interactionRadius = 1.8
	},
	{
		id = 'mirror_park',
		name = '24/7 Supermarket',
		subtitle = 'Snacks, first aid, and quick supplies.',
		catalogId = 'essentials',
		interaction = vector3(1135.79, -982.28, 46.42),
		interactionRadius = 1.8
	},
	{
		id = 'little_seoul',
		name = '24/7 Supermarket',
		subtitle = 'Snacks, first aid, and quick supplies.',
		catalogId = 'essentials',
		interaction = vector3( -707.31, -913.71, 19.22),
		interactionRadius = 1.8
	},
	{
		id = 'banham_canyon',
		name = '24/7 Supermarket',
		subtitle = 'Snacks, first aid, and quick supplies.',
		catalogId = 'essentials',
		interaction = vector3(-3040.68, 584.54, 7.91),
		interactionRadius = 1.8
	},
	{
		id = 'chumash',
		name = '24/7 Supermarket',
		subtitle = 'Snacks, first aid, and quick supplies.',
		catalogId = 'essentials',
		interaction = vector3(-3243.99, 1000.14, 12.83),
		interactionRadius = 1.8
	},
	{
		id = 'route68',
		name = '24/7 Supermarket',
		subtitle = 'Snacks, first aid, and quick supplies.',
		catalogId = 'essentials',
		interaction = vector3(1164.86, 2708.38, 38.16),
		interactionRadius = 1.8
	},
	{
		id = 'senora_fwy',
		name = '24/7 Supermarket',
		subtitle = 'Snacks, first aid, and quick supplies.',
		catalogId = 'essentials',
		interaction = vector3(2677.93, 3280.85, 55.24),
		interactionRadius = 1.8
	},
	{
		id = 'grapeseed',
		name = '24/7 Supermarket',
		subtitle = 'Snacks, first aid, and quick supplies.',
		catalogId = 'essentials',
		interaction = vector3(1961.42, 3740.92, 32.34),
		interactionRadius = 1.8
	},
	{
		id = 'paleto',
		name = '24/7 Supermarket',
		subtitle = 'Snacks, first aid, and quick supplies.',
		catalogId = 'essentials',
		interaction = vector3(1729.29, 6414.56, 35.04),
		interactionRadius = 1.8
	}
}