@echo off
setlocal enabledelayedexpansion
title Hysteria 一键安装脚本

:: 设置颜色
color 0A

:: 创建安装目录
set INSTALL_DIR=D:\Hysteria
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
cd /d "%INSTALL_DIR%"

echo ====================================================
echo             Hysteria 一键安装脚本
echo ====================================================
echo.
echo  此脚本将帮助您安装和配置 Hysteria 客户端
echo.
echo  1. 安装 Hysteria v1
echo  2. 安装 Hysteria v2
echo  3. 配置 Hysteria
echo  4. 启动 Hysteria
echo  5. 创建开机启动
echo  6. 退出
echo.
echo ====================================================

:menu
set /p choice=请输入选项 [1-6]: 

if "%choice%"=="1" goto install_v1
if "%choice%"=="2" goto install_v2
if "%choice%"=="3" goto configure
if "%choice%"=="4" goto start_hysteria
if "%choice%"=="5" goto create_startup
if "%choice%"=="6" goto end

echo 无效的选项，请重新输入
goto menu

:install_v1
echo.
echo 正在下载 Hysteria v1...
curl -L -o "%INSTALL_DIR%\hysteria-v1.exe" https://github.com/apernet/hysteria/releases/download/v1.3.5/hysteria-windows-amd64.exe
if %errorlevel% neq 0 (
    echo 下载失败，请检查网络连接
    goto menu
)
echo Hysteria v1 下载完成！
goto menu

:install_v2
echo.
echo 正在下载 Hysteria v2...
curl -L -o "%INSTALL_DIR%\hysteria-v2.exe" https://github.com/apernet/hysteria/releases/download/app/v2.6.1/hysteria-windows-amd64.exe
if %errorlevel% neq 0 (
    echo 下载失败，请检查网络连接
    goto menu
)
echo Hysteria v2 下载完成！
goto menu

:configure
echo.
echo 配置 Hysteria
echo.
set /p version=请选择版本 [1=v1/2=v2]: 
set /p server=请输入服务器地址和端口 (例如: example.com:443): 
set /p auth=请输入认证密钥: 
set /p obfs=请输入混淆密钥 (可选): 

if "%version%"=="1" (
    echo {> "%INSTALL_DIR%\config.json"
    echo   "server": "%server%",>> "%INSTALL_DIR%\config.json"
    echo   "auth_str": "%auth%",>> "%INSTALL_DIR%\config.json"
    if not "%obfs%"=="" echo   "obfs": "%obfs%",>> "%INSTALL_DIR%\config.json"
    echo   "insecure": true,>> "%INSTALL_DIR%\config.json"
    echo   "up_mbps": 10,>> "%INSTALL_DIR%\config.json"
    echo   "down_mbps": 50,>> "%INSTALL_DIR%\config.json"
    echo   "retry": 3,>> "%INSTALL_DIR%\config.json"
    echo   "retry_interval": 5,>> "%INSTALL_DIR%\config.json"
    echo   "socks5": {>> "%INSTALL_DIR%\config.json"
    echo     "listen": "127.0.0.1:1080">> "%INSTALL_DIR%\config.json"
    echo   },>> "%INSTALL_DIR%\config.json"
    echo   "http": {>> "%INSTALL_DIR%\config.json"
    echo     "listen": "127.0.0.1:8080">> "%INSTALL_DIR%\config.json"
    echo   }>> "%INSTALL_DIR%\config.json"
    echo }>> "%INSTALL_DIR%\config.json"
) else (
    echo {> "%INSTALL_DIR%\config.json"
    echo   "server": "%server%",>> "%INSTALL_DIR%\config.json"
    echo   "auth": "%auth%",>> "%INSTALL_DIR%\config.json"
    echo   "tls": {>> "%INSTALL_DIR%\config.json"
    echo     "insecure": true>> "%INSTALL_DIR%\config.json"
    echo   },>> "%INSTALL_DIR%\config.json"
    if not "%obfs%"=="" echo   "obfs": "%obfs%",>> "%INSTALL_DIR%\config.json"
    echo   "bandwidth": {>> "%INSTALL_DIR%\config.json"
    echo     "up": "10 mbps",>> "%INSTALL_DIR%\config.json"
    echo     "down": "50 mbps">> "%INSTALL_DIR%\config.json"
    echo   },>> "%INSTALL_DIR%\config.json"
    echo   "socks5": {>> "%INSTALL_DIR%\config.json"
    echo     "listen": "127.0.0.1:1080">> "%INSTALL_DIR%\config.json"
    echo   },>> "%INSTALL_DIR%\config.json"
    echo   "http": {>> "%INSTALL_DIR%\config.json"
    echo     "listen": "127.0.0.1:8080">> "%INSTALL_DIR%\config.json"
    echo   }>> "%INSTALL_DIR%\config.json"
    echo }>> "%INSTALL_DIR%\config.json"
)

echo 配置文件已创建: %INSTALL_DIR%\config.json
goto menu

:start_hysteria
echo.
echo 启动 Hysteria
echo.
set /p version=请选择版本 [1=v1/2=v2]: 

if "%version%"=="1" (
    if not exist "%INSTALL_DIR%\hysteria-v1.exe" (
        echo Hysteria v1 未安装，请先安装
        goto menu
    )
    start "" "%INSTALL_DIR%\hysteria-v1.exe" client -c "%INSTALL_DIR%\config.json"
) else (
    if not exist "%INSTALL_DIR%\hysteria-v2.exe" (
        echo Hysteria v2 未安装，请先安装
        goto menu
    )
    start "" "%INSTALL_DIR%\hysteria-v2.exe" client -c "%INSTALL_DIR%\config.json"
)

echo Hysteria 已启动
goto menu

:create_startup
echo.
echo 创建开机启动脚本
echo.
set /p version=请选择版本 [1=v1/2=v2]: 

echo @echo off> "%INSTALL_DIR%\startup.bat"
echo cd /d "%INSTALL_DIR%">> "%INSTALL_DIR%\startup.bat"
if "%version%"=="1" (
    echo :start>> "%INSTALL_DIR%\startup.bat"
    echo hysteria-v1.exe client -c config.json>> "%INSTALL_DIR%\startup.bat"
    echo timeout /t 5 > nul>> "%INSTALL_DIR%\startup.bat"
    echo goto start>> "%INSTALL_DIR%\startup.bat"
) else (
    echo :start>> "%INSTALL_DIR%\startup.bat"
    echo hysteria-v2.exe client -c config.json>> "%INSTALL_DIR%\startup.bat"
    echo timeout /t 5 > nul>> "%INSTALL_DIR%\startup.bat"
    echo goto start>> "%INSTALL_DIR%\startup.bat"
)

echo 创建开机启动快捷方式...
echo Set oWS = WScript.CreateObject("WScript.Shell")> "%TEMP%\CreateShortcut.vbs"
echo sLinkFile = oWS.SpecialFolders("Startup") ^& "\Hysteria.lnk">> "%TEMP%\CreateShortcut.vbs"
echo Set oLink = oWS.CreateShortcut(sLinkFile)>> "%TEMP%\CreateShortcut.vbs"
echo oLink.TargetPath = "%INSTALL_DIR%\startup.bat">> "%TEMP%\CreateShortcut.vbs"
echo oLink.WorkingDirectory = "%INSTALL_DIR%">> "%TEMP%\CreateShortcut.vbs"
echo oLink.Description = "Hysteria 自动启动">> "%TEMP%\CreateShortcut.vbs"
echo oLink.WindowStyle = 7>> "%TEMP%\CreateShortcut.vbs"
echo oLink.Save>> "%TEMP%\CreateShortcut.vbs"
cscript /nologo "%TEMP%\CreateShortcut.vbs"
del "%TEMP%\CreateShortcut.vbs"

echo 开机启动脚本已创建
goto menu

:end
echo.
echo 感谢使用 Hysteria 一键安装脚本！
echo.
pause
exit
