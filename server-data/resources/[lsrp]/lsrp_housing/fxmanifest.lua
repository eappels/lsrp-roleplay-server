fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'GitHub Copilot'
description 'LSRP Housing'
version '1.0.0'

dependencies {
	'oxmysql',
	'lsrp_framework',
	'lsrp_inventory'
}

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
	'html/app.js',
	'sql/create_apartments.sql'
}