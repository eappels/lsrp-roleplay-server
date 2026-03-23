fx_version 'cerulean'
game 'gta5'

author 'Eddy Appels'
description 'LSRP Dev'

dependencies {
    'lsrp_spawner',
    'oxmysql',
    'lsrp_vehicleparking',
    'lsrp_core'
}

client_scripts {
    'client/client.lua',
    'client/noclip.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua'
}