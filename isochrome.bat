@echo off
setlocal EnableExtensions EnableDelayedExpansion
set "SITE=https://lmarena.ai/"
set "LOG_PREFIX==[LmarenaGuest]"

call :generate_stamp
set "RANDOM_SUFFIX=!RANDOM!!RANDOM!"
set "UNIQUE_PROFILE_ID=lmarena_!STAMP!_!RANDOM_SUFFIX!"
set "PROFILE_DIR=%TEMP%\!UNIQUE_PROFILE_ID!"

echo %LOG_PREFIX% Создаём изолированную сессию
echo        ID профиля: !UNIQUE_PROFILE_ID!
echo        Путь:       !PROFILE_DIR!

call :find_chrome
if not defined CHROME_EXE (
    echo %LOG_PREFIX% [Ошибка] Не удалось найти исполняемый файл Chrome.
    echo            Проверь путь или установи Chrome.
    timeout /t 10 >nul
    exit /b 1
)

if not exist "!PROFILE_DIR!" (
    mkdir "!PROFILE_DIR!" >nul 2>&1
)

echo %LOG_PREFIX% Запускаем Chrome с временным профилем...
echo        Ожидаем закрытия браузера для автоматической очистки.
"!CHROME_EXE!" --new-window --user-data-dir="!PROFILE_DIR!" "!SITE!"
set "CHROME_EXIT_CODE=%ERRORLEVEL%"

echo %LOG_PREFIX% Chrome завершён (код !CHROME_EXIT_CODE!). Удаляем профиль...
if exist "!PROFILE_DIR!" (
    rmdir /s /q "!PROFILE_DIR!" >nul 2>&1
    if exist "!PROFILE_DIR!" (
        echo %LOG_PREFIX% [Предупреждение] Не удалось удалить профиль автоматически.
        echo            Удалите вручную: !PROFILE_DIR!
    ) else (
        echo %LOG_PREFIX% [OK] Временный профиль удалён.
    )
) else (
    echo %LOG_PREFIX% Папка профиля отсутствует (возможно, удалена вручную).
)

echo %LOG_PREFIX% Сессия завершена.
timeout /t 2 >nul
exit /b 0

:generate_stamp
set "STAMP="
for /f "tokens=2 delims==." %%I in ('wmic os get LocalDateTime /value ^| find "="') do set "STAMP=%%I"
if defined STAMP (
    set "STAMP=!STAMP:~0,14!"
) else (
    set "STAMP=%date:~-4%%date:~3,2%%date:~0,2%%time:~0,2%%time:~3,2%%time:~6,2%"
    set "STAMP=!STAMP: =0!"
)
exit /b 0

:find_chrome
set "CHROME_EXE="
for %%P in (
    "%ProgramFiles%\Google\Chrome\Application\chrome.exe"
    "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
    "%LocalAppData%\Google\Chrome\Application\chrome.exe"
) do (
    if exist %%~P (
        set "CHROME_EXE=%%~P"
        goto :EOF
    )
)
goto :EOF
