fx_version 'cerulean'
game 'gta5'
lua54 'yes'

games {
  "gta5",
  "rdr3"
}

ui_page 'ui/index.html'

dependencies {
  'oxmysql',
  'lsrp_dev',
  'lsrp_framework'
}

shared_scripts {
  "shared/framework.lua",
  "shared/items.lua",
  "shared/locale.lua",
  "shared/config.lua",
}

client_scripts {
  "client/vehicle.lua",
  "client/clothing.lua",
  "client/trunk.lua",
  "client/blips.lua",
  "client/stretcher.lua",
  "client/main.lua",
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  "server/server.lua",
  "server/trunk.lua",
  "server/stretcher.lua",
}

files {
  'ui/index.html',
  'ui/**/*',
}

escrow_ignore {
  "shared/*.lua",
  "client/*.lua",
  "server/*.lua",
}

dependency '/assetpacks'