fx_version 'cerulean'
game 'gta5'

author 'LSRP Development'
description 'Framework-native handheld radio wrapper over pma-voice'
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
	'pma-voice'
}