Config = Config or {}

Config.Inventory = {
	enabled = true,
	defaultSlots = 12,
	maxWeight = 25000,
	maxStack = 10,
	transferRange = 4.0,
	pickupRange = 2.0,
	dropLifetimeSeconds = 900,
	starterItems = {
		{ name = 'phone', amount = 1 },
		{ name = 'burger', amount = 2 },
		{ name = 'cola', amount = 2 },
		{ name = 'bandage', amount = 3 }
	}
}

Config.Items = {
	phone = {
		label = 'Phone',
		weight = 250,
		maxStack = 1,
		image = 'phone-COQO-GzR.png',
		description = 'Your personal phone.'
	},
	burger = {
		label = 'Burger',
		weight = 350,
		maxStack = 10,
		image = 'burger-WvWkGmk7.png',
		description = 'Fast food that actually helps.'
	},
	cola = {
		label = 'Cola',
		weight = 300,
		maxStack = 10,
		image = 'cola-Db24EFMX.png',
		description = 'Cold and sugary.'
	},
	bandage = {
		label = 'Bandage',
		weight = 150,
		maxStack = 10,
		image = 'bandage-Br_-nzB2.png',
		description = 'Basic first aid.'
	},
	lockpick = {
		label = 'Lockpick',
		weight = 100,
		maxStack = 5,
		image = 'lockpick-BY_OMax9.png',
		description = 'Useful when a key is missing.'
	},
	joint = {
		label = 'Joint',
		weight = 50,
		maxStack = 10,
		image = 'joint-B6xGll5e.png',
		description = 'Handle responsibly.'
	}
}
