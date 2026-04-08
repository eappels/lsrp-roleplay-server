fx_version 'cerulean'
game 'gta5'

author 'LSRP Development'
description 'LSRP EMS starter resource built on lsrp_framework'
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
	'lsrp_spawner'
}