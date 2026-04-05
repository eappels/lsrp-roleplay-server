fx_version 'cerulean'
game 'gta5'

author 'LSRP'
description 'LSRP Core shared configuration'

shared_scripts {
    'shared/config.lua'
}

client_scripts {
    'client/minimap.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/connection_gate.lua',
    'server/identity.lua',
    'server/characters.lua',
    'server/prejoin_auth.lua',
    'server/server.lua'
}

dependency 'oxmysql'