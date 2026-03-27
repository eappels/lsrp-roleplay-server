fx_version 'cerulean'
game 'gta5'

author 'LSRP'
description 'LSRP Core shared configuration'

shared_scripts {
    'shared/config.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/identity.lua',
    'server/prejoin_auth.lua',
    'server/server.lua'
}

dependency 'oxmysql'