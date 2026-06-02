fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'clearwork'
description 'ClearWork Core'
version '0.4.5'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/schema.lua',
    'server/players.lua',
    'server/characters.lua',
    'server/main.lua'
}
