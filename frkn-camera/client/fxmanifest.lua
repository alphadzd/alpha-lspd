fx_version 'cerulean'
game 'gta5'
escrow_ignore {
	'client/*.lua',
	'server/*.lua',
	'shared/*.lua',
	'locales/*.lua',
}
shared_scripts {
	"@ox_lib/init.lua",
	'shared/locale.lua',
	'locales/en.lua',
	'locales/*.lua',
	'shared/cores.lua',
    'shared/config.lua',
}
client_scripts {
	'client/*.lua'
}
server_scripts {
	'@mysql-async/lib/MySQL.lua',
	'server/*.lua'
}
ui_page 'html/index.html'
files {
	'html/index.html',
	'html/style.css',
	'html/images/*.png',
	'html/images/*.jpg',
	'html/images/*.webp',
	'html/images/*.svg',
	'html/fonts/*.ttf',	
	'html/fonts/*.otf',	
	'html/script.js',
	'html/*png',
	'html/*jpg',
	'html/*webp',
	'html/images/*.gif',
}

lua54 'yes'
dependency '/assetpacks'

game "gta5"
this_is_a_map 'yes'

dependency '/assetpacks'
dependency '/assetpacks'
dependency '/assetpacks'