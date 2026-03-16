fx_version 'cerulean'
game 'gta5'

author 'LSRP'
description 'LSRP Zone System - Proximity zones that open resource UIs'
version '1.0.0'

shared_scripts {
    'shared/config.lua'
}

client_scripts {
    '@polyzone/client.lua',
    '@polyzone/CircleZone.lua',
    'client/client.lua'
}
