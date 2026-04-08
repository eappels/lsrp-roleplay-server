fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'LSRP Development'
description 'Vehicle fuel consumption and gas station refueling for LSRP'
version '1.0.0'

shared_scripts {
    'shared/config.lua'
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