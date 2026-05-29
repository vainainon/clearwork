fx_version 'cerulean'
game 'rdr3'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'clearwork'
description 'ClearWork Core'
version '0.1.0'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/schema.lua',
    'server/main.lua'
}