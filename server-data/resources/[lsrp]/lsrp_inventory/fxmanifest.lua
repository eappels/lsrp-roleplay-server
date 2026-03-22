fx_version 'cerulean'
game 'gta5'

author 'LSRP'
description 'LSRP Inventory rebuilt from scratch'
version '2.0.0'

lua54 'yes'

shared_scripts {
	'shared/config.lua'
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/style.css',
	'html/script.js',
	'html/images/*.png'
}

client_scripts {
	'client/client.lua'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/server.lua'
}

dependencies {
	'oxmysql'
}
