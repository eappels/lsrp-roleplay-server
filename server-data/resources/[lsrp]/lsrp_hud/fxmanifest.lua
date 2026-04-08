fx_version 'cerulean'
game 'gta5'

author 'LSRP'
description 'Standalone compass and coordinate HUD'

ui_page 'ui/index.html'

shared_scripts {
	'@lsrp_core/shared/config.lua'
}

client_scripts {
	'client/client.lua'
}

files {
	'ui/index.html',
	'ui/hud.css',
	'ui/hud.js',
	'ui/assets/app.css',
	'ui/assets/app.js'
}

dependencies {
	'lsrp_core',
	'lsrp_framework'
}