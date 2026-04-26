lsrpBootstrapConfig = {
	healthCheckDelayMs = 1500,
	resourceStartTimeoutMs = 8000,
	closeConnectionsOnFailure = true,
	openConnectionsOnSuccess = true,
	criticalResources = {
		'chat',
		'oxmysql',
		'polyzone',
		'pma-voice',
		'lsrp_core',
		'lsrp_economy',
		'lsrp_jobs',
		'lsrp_inventory',
		'lsrp_framework'
	},
	phases = {
		{
			name = 'player-journey',
			resources = {
				{ name = 'lsrp_hud', required = false },
				{ name = 'lsrp_dev', required = false },
				{ name = 'lsrp_nui_template', required = false },
				{ name = 'codem-supreme-radialmenu', required = false },
				{ name = 'lsrp_radio', required = false },
				{ name = 'lsrp_mdt', required = false },
				{ name = 'lsrp_hunger', required = false },
				{ name = 'lsrp_shops', required = false },
				{ name = 'lsrp_housing', required = true },
				{ name = 'lsrp_loadscreen', required = true },
				{ name = 'lsrp_spawner', required = true },
				{ name = 'lsrp_pededitor', required = false },
				{ name = 'lsrp_vehicleeditor', required = false },
				{ name = 'lsrp_vehiclebehaviour', required = false },
				{ name = 'lsrp_vehicleparking', required = false },
				{ name = 'lsrp_policevehicleparking', required = false },
				{ name = 'lsrp_vehicleshop', required = false },
				{ name = 'lsrp_carwash', required = false },
				{ name = 'lsrp_zones', required = false },
				{ name = 'lsrp_mapedits', required = false },
				{ name = 'lsrp_phones', required = false }
			}
		},
		{
			name = 'services',
			resources = {
				{ name = 'lsrp_ems', required = false },
				{ name = 'lsrp_jobcenter', required = false },
				{ name = 'lsrp_police', required = false },
				{ name = 'lsrp_taxi', required = false },
				{ name = 'lsrp_towing', required = false },
				{ name = 'lsrp_fuel', required = false },
				{ name = 'lsrp_hacking', required = false }
			}
		}
	}
}