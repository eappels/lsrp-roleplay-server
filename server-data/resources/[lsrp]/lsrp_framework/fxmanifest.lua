fx_version 'cerulean'
game 'gta5'

author 'LSRP'
description 'LSRP public framework facade'
lua54 'yes'

shared_scripts {
	'shared/contracts.lua'
}

client_scripts {
	'client/main.lua'
}

server_scripts {
	'server/main.lua'
}

dependencies {
	'lsrp_core',
	'lsrp_economy',
	'lsrp_jobs',
	'lsrp_inventory'
}