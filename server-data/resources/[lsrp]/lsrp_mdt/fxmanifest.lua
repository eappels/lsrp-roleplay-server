fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'LSRP Development'
description 'Starter MDT resource with duty-gated NUI shell'
version '1.0.0'

ui_page 'html/index.html'

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

files {
	'html/index.html',
	'html/style.css',
	'html/script.js'
}

dependencies {
	'lsrp_framework',
	'oxmysql'
}