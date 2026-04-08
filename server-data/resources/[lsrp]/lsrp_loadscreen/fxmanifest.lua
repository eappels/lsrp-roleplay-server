fx_version 'cerulean'
game 'gta5'

author 'Eddy Appels'
description 'LSRP Loadscreen'

loadscreen_manual_shutdown 'yes'
loadscreen 'loadscreen.html'

client_scripts {
    'client/client.lua'
}

dependencies {
    'lsrp_spawner',
    'lsrp_framework'
}

files {
    'loadscreen.html',
    'style.css',
    'image-generator.png'
}