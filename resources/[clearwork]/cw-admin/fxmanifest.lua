fx_version 'cerulean'
game 'rdr3'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'clearwork'
description 'ClearWork Admin System'
version '0.3.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',

    'server/config.lua',
    'server/core.lua',
    'server/roles.lua',
    'server/characters.lua',
    'server/players.lua',
    'server/tools.lua',
    'server/main.lua'
}

client_scripts {
    'client/tools.lua',
    'client/main.lua'
}

dependency 'oxmysql'