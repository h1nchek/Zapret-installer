@echo off
setlocal EnableExtensions
chcp 65001 >nul
title Zapret installer (Windows)

rem ===========================================================================
rem  install-windows.bat
rem  Скачивает последний релиз Flowseal/zapret-discord-youtube и раскладывает
rem  его в C:\zapret. Для автозапуска дальше используется штатный service.bat.
rem ===========================================================================

set "REPO=Flowseal/zapret-discord-youtube"
set "DEST=C:\zapret"
set "ZIP=%TEMP%\zapret_release.zip"
set "TMPX=%TEMP%\zapret_extract"
set "TAGFILE=%TEMP%\zapret_tag.txt"

rem ---------- права администратора (нужны для службы и WinDivert) -----------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Нужны права администратора, перезапускаюсь...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:menu
cls
echo ============================================================
echo   Zapret для Windows  (Flowseal/zapret-discord-youtube)
echo ============================================================
echo.
echo   Папка установки: %DEST%
echo.
echo   1. Скачать / обновить
echo   2. Открыть service.bat (автозапуск, удаление службы, hosts)
echo   3. Быстрый тест: запустить general.bat
echo   4. Сменить папку установки
echo   5. Справка по удалению
echo   0. Выход
echo.
set "CH="
set /p "CH=Выбор: "
if "%CH%"=="1" goto install
if "%CH%"=="2" goto service
if "%CH%"=="3" goto general
if "%CH%"=="4" goto setdest
if "%CH%"=="5" goto uninstall
if "%CH%"=="0" exit /b 0
goto menu

:setdest
echo.
echo Лучше путь без пробелов и кириллицы, например C:\zapret
set "NEWDEST="
set /p "NEWDEST=Новая папка (Enter - оставить как есть): "
if defined NEWDEST set "DEST=%NEWDEST%"
goto menu

:install
echo.
echo [1/4] Проверка запущенного winws.exe...
tasklist /fi "imagename eq winws.exe" 2>nul | find /i "winws.exe" >nul
if %errorlevel%==0 (
    echo.
    echo   ! winws.exe сейчас запущен и может блокировать файлы.
    echo   ! Закрой окно со стратегией или удали службу через service.bat ^(пункт Remove Services^).
    echo.
    pause
    goto menu
)

echo [2/4] Ищу последний релиз и скачиваю архив...
if exist "%ZIP%" del /f /q "%ZIP%"
if exist "%TAGFILE%" del /f /q "%TAGFILE%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $r=Invoke-RestMethod 'https://api.github.com/repos/%REPO%/releases/latest' -Headers @{'User-Agent'='zapret-installer'}; $a=$r.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1; if(-not $a){ Write-Host 'В релизе нет zip-архива'; exit 2 }; Invoke-WebRequest $a.browser_download_url -OutFile '%ZIP%' -UseBasicParsing; Set-Content -Path '%TAGFILE%' -Value $r.tag_name"
if %errorlevel% neq 0 (
    echo.
    echo   X Не удалось скачать релиз. Проверь интернет или скачай вручную:
    echo     https://github.com/%REPO%/releases
    echo.
    pause
    goto menu
)
set "TAG=?"
if exist "%TAGFILE%" set /p TAG=<"%TAGFILE%"
echo   Версия: %TAG%

echo [3/4] Распаковка...
if exist "%TMPX%" rmdir /s /q "%TMPX%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Expand-Archive -Path '%ZIP%' -DestinationPath '%TMPX%' -Force; $s=Get-ChildItem -Path '%TMPX%' -Recurse -Filter service.bat | Select-Object -First 1; if(-not $s){ Write-Host 'service.bat не найден в архиве'; exit 3 }; Set-Content -Path '%TMPX%\_root.txt' -Value $s.DirectoryName"
if %errorlevel% neq 0 (
    echo.
    echo   X Не удалось распаковать архив.
    pause
    goto menu
)
set /p ROOT=<"%TMPX%\_root.txt"

echo [4/4] Копирую в %DEST%...
if not exist "%DEST%" mkdir "%DEST%"
if exist "%DEST%\lists" (
    robocopy "%DEST%\lists" "%DEST%\_backup_lists" /E /NFL /NDL /NJH /NJS /NP >nul
    echo   Бэкап твоих списков: %DEST%\_backup_lists
)
if exist "%DEST%\list-general.txt" copy /y "%DEST%\list-general.txt" "%DEST%\list-general.txt.bak" >nul
robocopy "%ROOT%" "%DEST%" /E /NFL /NDL /NJH /NJS /NP >nul
if %errorlevel% geq 8 (
    echo.
    echo   X Ошибка копирования файлов.
    pause
    goto menu
)

del /f /q "%ZIP%" 2>nul
rmdir /s /q "%TMPX%" 2>nul
del /f /q "%TAGFILE%" 2>nul

echo.
echo   ✔ Готово: %DEST%  ^(версия %TAG%^)
echo.
echo   Дальше:
echo     - пункт 3: проверь, открываются ли YouTube/Discord через general.bat
echo     - если нет, попробуй другие general ^(ALT^).bat из папки
echo     - когда нашёл рабочий: пункт 2 -^> Install Service ^(автозапуск^)
echo.
echo   Антивирус может ругаться на WinDivert (драйвер перехвата трафика).
echo   Проверяй, откуда скачал, и при желании собери бинарники сам.
echo.
pause
goto menu

:service
if not exist "%DEST%\service.bat" (
    echo.
    echo   service.bat не найден в %DEST%. Сначала пункт 1.
    pause
    goto menu
)
pushd "%DEST%"
call service.bat
popd
goto menu

:general
if not exist "%DEST%\general.bat" (
    echo.
    echo   general.bat не найден в %DEST%. Сначала пункт 1.
    pause
    goto menu
)
echo.
echo   Запускаю general.bat в новом окне. Должен появиться winws.exe.
echo   Окно не закрывай, пока проверяешь YouTube и Discord.
pushd "%DEST%"
start "zapret" cmd /c general.bat
popd
pause
goto menu

:uninstall
cls
echo ============================================================
echo   Как удалить
echo ============================================================
echo.
echo   1. Пункт 2 в этом меню ^(service.bat^) -^> Remove Services.
echo   2. Закрой окно с general.bat, если оно открыто.
echo   3. Удали папку %DEST%.
echo.
echo   Это единственные шаги, которые знает service.bat; ничего лишнего
echo   этот установщик в систему не ставит.
echo.
pause
goto menu
