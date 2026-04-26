fx_version 'cerulean'
game 'gta5'

author 'LSRP'
description 'LSRP phased startup bootstrap'
lua54 'yes'

shared_scripts {
	'shared/config.lua'
}

server_scripts {
	'server/main.lua'
}

dependencies {
	'lsrp_core',
	'lsrp_economy',
	'lsrp_jobs',
	'lsrp_inventory',
	'lsrp_framework'
}