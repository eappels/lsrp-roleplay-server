fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'Eddy Appels'
description 'LSRP Economy System'
version '1.0.0'

dependencies {
    'oxmysql'
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