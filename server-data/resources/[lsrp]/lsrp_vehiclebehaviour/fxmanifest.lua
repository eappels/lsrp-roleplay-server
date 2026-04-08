fx_version 'cerulean'
game 'gta5'

author 'LSRP'
description 'LSRP Vehicle Behaviour'
version '1.0.0'

lua54 'yes'

dependency 'lsrp_framework'
dependency 'oxmysql'

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

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/style.css',
	'html/script.js'
}
