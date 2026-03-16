fx_version 'cerulean'
game 'gta5'

author 'Eddy Appels'
description 'LSRP testing resource'

lua54 'yes'

shared_scripts {
	'shared/config.lua'
}

client_scripts {
	'@polyzone/client.lua',
	'@polyzone/BoxZone.lua',
	'client/client.lua'
}

server_scripts {
	'server/server.lua'
}