fx_version 'cerulean'
game 'gta5'

author 'Eddy Appels'
description 'LSRP Loadscreen'

loadscreen_manual_shutdown 'yes'
loadscreen 'loadscreen.html'

client_scripts {
    'client/client.lua'
}

dependency 'lsrp_spawner'

files {
    'loadscreen.html',
    'style.css',
    'image-generator.png'
}