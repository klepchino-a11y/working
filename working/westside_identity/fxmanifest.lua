fx_version 'adamant'

game 'gta5'
description 'Westside identity registration with Arabic-first UI and video background.'
lua54 'yes'
version '2.0.0'

shared_scripts {
	'@es_extended/imports.lua',
	'@es_extended/locale.lua',
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'locales/*.lua',
	'config.lua',
	'server/main.lua'
}

client_scripts {
	'locales/*.lua',
	'config.lua',
	'client/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/play.mp4'
}


dependency 'es_extended'
