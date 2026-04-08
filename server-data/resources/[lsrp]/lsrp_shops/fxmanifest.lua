fx_version 'cerulean'
game 'gta5'

author 'LSRP'
description 'LSRP convenience stores and item purchases'
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

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/style.css',
	'html/script.js'
}

dependencies {
	'lsrp_framework'
}