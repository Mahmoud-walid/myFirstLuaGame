@echo off
setlocal
IF "%*"=="" (set I=-i) ELSE (set I=)
set "LUAROCKS_SYSCONFDIR=C:\Program Files\luarocks"
"C:\Users\modyw\scoop\apps\lua\current\bin\lua.exe" -e "package.path=\"F:\\Mahmoud_Walid\\progects\\Work\\lua\\myFirstLuaGame\\lua_modules\\share\\lua\\5.4\\?.lua;F:\\Mahmoud_Walid\\progects\\Work\\lua\\myFirstLuaGame\\lua_modules\\share\\lua\\5.4\\?\\init.lua;F:\\Mahmoud_Walid\\progects\\Work\\lua\\myFirstLuaGame\\lib\\share\\lua\\5.4\\?.lua;F:\\Mahmoud_Walid\\progects\\Work\\lua\\myFirstLuaGame\\lib\\share\\lua\\5.4\\?\\init.lua;C:\\Users\\modyw\\scoop\\apps\\luarocks\\current\\rocks\\share\\lua\\5.4\\?.lua;C:\\Users\\modyw\\scoop\\apps\\luarocks\\current\\rocks\\share\\lua\\5.4\\?\\init.lua;\"..package.path;package.cpath=\"F:\\Mahmoud_Walid\\progects\\Work\\lua\\myFirstLuaGame\\lua_modules\\lib\\lua\\5.4\\?.dll;F:\\Mahmoud_Walid\\progects\\Work\\lua\\myFirstLuaGame\\lib\\lib\\lua\\5.4\\?.dll;C:\\Users\\modyw\\scoop\\apps\\luarocks\\current\\rocks\\lib\\lua\\5.4\\?.dll;\"..package.cpath" %I% %*
exit /b %ERRORLEVEL%
