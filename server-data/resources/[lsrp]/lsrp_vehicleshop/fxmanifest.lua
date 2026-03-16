fx_version 'cerulean'
game 'gta5'

author 'LSRP'
description 'LSRP Vehicle Shop'
version '1.1.0'

lua54 'yes'

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

dependencies {
	'lsrp_core',
	'lsrp_economy',
	'lsrp_vehicleparking',
	'oxmysql'
}
