fx_version 'cerulean'
game 'gta5'

author 'LSRP Development'
description 'LSRP Phone System'
version '1.0.0'

dependencies {
	'oxmysql',
    'lsrp_framework',
    'lsrp_vehicleparking',
    'lsrp_taxi',
    'pma-voice'
}

ui_page 'html/index.html'

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
