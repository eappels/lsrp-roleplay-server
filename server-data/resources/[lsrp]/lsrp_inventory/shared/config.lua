Config = Config or {}

Config.Inventory = {
	enabled = true,
	defaultSlots = 15,
	maxWeight = 25000,
	maxStack = 10,
	transferRange = 4.0,
	pickupRange = 2.0,
	dropLifetimeSeconds = 900,
	starterItems = {}
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
		description = 'Fast food that actually helps.',
		use = {
			label = 'Eat',
			mode = 'anim',
			animDict = 'mp_player_inteat@burger',
			animName = 'mp_player_int_eat_burger_fp',
			flag = 49,
			durationMs = 10000,
			consumeAmount = 1,
			requireOnFoot = true
		}
	},
	bandage = {
		label = 'Bandage',
		weight = 150,
		maxStack = 10,
		image = 'bandage-Br_-nzB2.png',
		description = 'Basic first aid.',
		use = {
			label = 'Apply',
			mode = 'anim',
			animDict = 'amb@medic@standing@tendtodead@base',
			animName = 'base',
			flag = 49,
			durationMs = 10000,
			consumeAmount = 1,
			requireOnFoot = true,
			effect = {
				type = 'heal',
				amount = 25
			}
		}
	},
	lockpick = {
		label = 'Lockpick',
		weight = 100,
		maxStack = 5,
		image = 'lockpick-BY_OMax9.png',
		description = 'Useful when a key is missing.'
	},
	WEAPON_HACKINGDEVICE = {
		label = 'Hacking Device',
		weight = 1500,
		maxStack = 1,
		image = 'hackingdevice-DLgIotFO.png',
		description = 'A specialized electronic device for ATM intrusion.',
		use = {
			label = 'Hack ATM',
			mode = 'none',
			durationMs = 1000,
			consumeAmount = 0,
			requireOnFoot = true,
			effect = {
				type = 'atm_hacking_animation',
				maxDistance = 1.8
			}
		}
	},
	gascan = {
		label = 'Gas Can',
		weight = 2500,
		maxStack = 1,
		image = 'gasoline-D7lxSjl8.png',
		description = 'A portable gasoline can for emergency refueling.',
		use = {
			label = 'Refuel Vehicle',
			mode = 'anim',
			animDict = 'amb@world_human_security_shine_torch@male@base',
			animName = 'base',
			flag = 1,
			durationMs = 10000,
			consumeAmount = 1,
			requireOnFoot = true,
			effect = {
				type = 'vehicle_refuel_amount',
				amount = 20.0,
				maxDistance = 5.5
			}
		}
	},
	repairkit = {
		label = 'Repair Kit',
		weight = 1800,
		maxStack = 2,
		image = 'repairkit-CuvccWdB.png',
		description = 'Basic tools and parts for quick roadside repairs.',
		use = {
			label = 'Repair Vehicle',
			mode = 'anim',
			animDict = 'mp_car_bomb',
			animName = 'car_bomb_mechanic',
			flag = 49,
			durationMs = 10000,
			consumeAmount = 1,
			requireOnFoot = true,
			effect = {
				type = 'vehicle_repair_full',
				maxDistance = 5.5
			}
		}
	},
	joint = {
		label = 'Joint',
		weight = 50,
		maxStack = 10,
		image = 'joint-B6xGll5e.png',
		description = 'Handle responsibly.',
		use = {
			label = 'Smoke',
			mode = 'scenario',
			scenario = 'WORLD_HUMAN_SMOKING_POT',
			durationMs = 10000,
			consumeAmount = 1,
			requireOnFoot = true
		}
	}
}
