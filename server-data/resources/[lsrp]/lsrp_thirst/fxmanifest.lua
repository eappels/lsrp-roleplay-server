fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'LSRP'
description 'Persistent thirst system for LSRP players'
version '1.0.0'

shared_scripts {
	'shared/config.lua'
}

client_scripts {
	'client/client.lua'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/server.lua'
}

dependencies {
	'lsrp_core',
	'oxmysql'
}