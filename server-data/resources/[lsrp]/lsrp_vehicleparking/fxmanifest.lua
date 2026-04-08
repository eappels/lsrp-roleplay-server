fx_version 'cerulean'
game 'gta5'

author 'LSRP'
description 'Vehicle Parking System with Zones and UI'
version '1.0.0'

shared_scripts {
    'shared/config.lua'
}

client_scripts {
    '@polyzone/client.lua',
    '@polyzone/BoxZone.lua',
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
    'oxmysql',
    'polyzone',
    'lsrp_framework'
}
