fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'WestSide المنطقة الغربية'
description 'WestSide (WS) themed loading screen inspired by Diriyah layout'
version '3.0.0'

loadscreen 'index.html'
loadscreen_manual_shutdown 'yes'

shared_script 'config.lua'
client_script 'client/client.lua'

files {
  'index.html',
  'assets/**/*',
    'vid/**/*',
  'WS_only.png'
}
