fx_version 'cerulean'

game 'gta5'

author 'Project Sloth & OK1ez'
version '2.2.1'

lua54 'yes'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'shared/**'
}

ui_page 'html/index.html'
-- ui_page 'http://localhost:5173/' --for dev

client_script {
    '@PolyZone/client.lua',
    '@PolyZone/CircleZone.lua',
    '@PolyZone/BoxZone.lua',
    'client/**'
}

server_script {
    '@oxmysql/lib/MySQL.lua',
    'server/**'
}

files {
    'locales/*.json',
    'html/index.html',
    'html/index.css',
    'html/index.js',
    'sounds/*.ogg'
}

ox_lib 'locale' -- v3.8.0 or above
