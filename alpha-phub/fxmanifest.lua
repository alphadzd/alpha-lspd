fx_version 'cerulean'
game 'gta5'

description 'Created By W Dev'
version '1.0.0'
author 'AlphaDev'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'shared/config.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    'server/server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/alpha.css',
    'html/js/alpha.js',
    'html/img/*.png'
}

lua54 'yes'