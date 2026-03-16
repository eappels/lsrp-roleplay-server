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

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua'
}