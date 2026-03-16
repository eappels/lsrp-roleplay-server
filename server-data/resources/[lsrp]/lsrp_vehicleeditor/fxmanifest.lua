fx_version 'cerulean'
game 'gta5'

author 'Eddy Appels'
description 'LSRP Vehicle Editor'

lua54 'yes'

dependency 'lsrp_core'
dependency 'oxmysql'

shared_scripts {
	'@lsrp_core/shared/config.lua'
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/style.css',
	'html/main.js'
}

client_scripts {
	'client/client.lua'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/server.lua'
}
