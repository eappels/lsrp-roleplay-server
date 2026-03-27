fx_version 'cerulean'
game 'gta5'

author 'LSRP Development'
description 'LSRP private police job with Mission Row duty and patrol vehicle access'
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
	'lsrp_jobs',
	'lsrp_vehicleparking'
}