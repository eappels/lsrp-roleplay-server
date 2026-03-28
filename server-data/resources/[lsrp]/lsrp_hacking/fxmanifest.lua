fx_version 'cerulean'
game 'gta5'

author 'LSRP Development'
description 'LSRP hacking resource scaffold'
version '1.0.0'

lua54 'yes'

shared_scripts {
	'shared/config.lua'
}

client_scripts {
	'client/client.lua'
}

server_scripts {
	'server/server.lua'
}

dependencies {
	'lsrp_core',
	'lsrp_economy',
	'lsrp_inventory'
}