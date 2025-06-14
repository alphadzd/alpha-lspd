fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Alpha Wings System'
description 'Wings System Interact Resource'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/main.lua'
}

dependencies {
    'qb-core',
    'interact',
    'ox_lib',
    'oxmysql'
}