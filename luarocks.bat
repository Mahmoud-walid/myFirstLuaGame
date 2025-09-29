@echo off
setlocal
set "LUAROCKS_SYSCONFDIR=C:\Program Files\luarocks"
"C:\Users\modyw\scoop\apps\luarocks\current\luarocks.exe" --project-tree F:\Mahmoud_Walid\progects\Work\lua\myFirstLuaGame\lua_modules %*
exit /b %ERRORLEVEL%
