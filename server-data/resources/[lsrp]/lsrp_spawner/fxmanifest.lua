fx_version 'cerulean'
game 'gta5'

author 'Eddy Appels'
description 'LSRP Spawner'

dependency 'lsrp_core'
dependency 'oxmysql'

shared_scripts {
    '@lsrp_core/shared/config.lua'
}

client_scripts {
    'client/client.lua'
}

ui_page 'ui/prejoin.html'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua'
}

files {
    'ui/prejoin.html',
    'ui/prejoin.css',
    'ui/prejoin.js'
}