fx_version 'cerulean'
game 'gta5'

author 'LSRP Development'
description 'LSRP private police job with Mission Row duty, wardrobe, and patrol vehicle access'
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
	'lsrp_framework',
	'lsrp_jobs',
	'lsrp_pededitor',
	'lsrp_vehicleparking'
}