fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'LSRP Development'
description 'LSRP vehicle carwash interaction with NUI'
version '1.0.0'

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