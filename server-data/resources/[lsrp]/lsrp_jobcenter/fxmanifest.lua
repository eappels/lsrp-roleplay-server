fx_version 'cerulean'
game 'gta5'

author 'LSRP Development'
description 'LSRP job center for civilian job browsing, applications, and resignations'
version '1.0.0'

shared_scripts {
	'shared/config.lua'
}

ui_page 'html/app.html'

files {
	'html/app.html',
	'html/index.html',
	'html/style.css',
	'html/script.js'
}

client_scripts {
	'client/client.lua'
}

server_scripts {
	'server/server.lua'
}

dependencies {
	'lsrp_framework'
}