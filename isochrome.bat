@echo off
setlocal EnableExtensions EnableDelayedExpansion

call :configure_codepage

set "APP_NAME=IsoChrome Lite IDE"
set "APP_VERSION=0.3.6"
set "PROFILE_STORE=%~dp0profiles"
set "QUICK_STORE=%PROFILE_STORE%\_quick"
set "THEME_CONFIG=%QUICK_STORE%\theme.cfg"
set "DEFAULT_THEME_ID=dark"
set "BOOKMARKS_FILE=%~dp0bookmarks.txt"
set "RECENT_LOG=%QUICK_STORE%\recent.log"
set "MAX_RECENT=20"
set "LOG_PREFIX=[IsoChrome]"
set "WORKER_STORE=%QUICK_STORE%\workers"
set "SCRIPT_PATH=%~f0"

call :ensure_profile_store
call :ensure_quick_store
call :ensure_theme_config
call :ensure_bookmarks_file
call :ensure_recent_log
call :ensure_worker_store
call :load_theme_config
call :apply_theme "%CURRENT_THEME_ID%"

if /i "%~1"=="--worker" (
    shift
    goto :quick_session_worker_entry
)

:main_menu
call :process_completed_workers
cls
echo ==================================================
echo   %APP_NAME%
echo   Версия: %APP_VERSION%
echo   Тема:   !CURRENT_THEME_DESC!
echo ==================================================
echo   Лёгкая IDE для изоляции Chrome:
echo     • Быстрая временная сессия без следов.
echo     • Создание и запуск персональных профилей.
echo     • Хранение закладок и истории запусков.
echo --------------------------------------------------
echo   1. Быстрая изолированная сессия (временный профиль)
echo   2. Создать постоянный профиль
echo   3. Запустить существующий профиль
echo   4. Удалить или очистить профиль
echo   5. Показать список профилей
echo   6. Управление закладками
echo   7. Настройки темы интерфейса
echo   0. Выход
echo --------------------------------------------------
set "MENU_CHOICE="
set /p "MENU_CHOICE=Ваш выбор: "
if "%MENU_CHOICE%"=="1" goto :quick_session
if "%MENU_CHOICE%"=="2" goto :create_profile
if "%MENU_CHOICE%"=="3" goto :launch_profile
if "%MENU_CHOICE%"=="4" goto :delete_profile
if "%MENU_CHOICE%"=="5" goto :show_profiles
if "%MENU_CHOICE%"=="6" goto :bookmarks_menu
if "%MENU_CHOICE%"=="7" goto :theme_menu
if "%MENU_CHOICE%"=="0" goto :exit_success
echo.
echo %LOG_PREFIX% [Ошибка] Неизвестный пункт меню.
call :wait_for_key
goto :main_menu

:quick_session
cls
echo %LOG_PREFIX% Быстрая изолированная сессия
call :obtain_url SESSION_URL ""

call :find_chrome
if not defined CHROME_EXE (
    echo %LOG_PREFIX% [Ошибка] Chrome не найден. Установите браузер.
    call :wait_for_key
    goto :main_menu
)

call :generate_stamp
set "RANDOM_SUFFIX=!RANDOM!!RANDOM!"
set "UNIQUE_PROFILE_ID=temp_!STAMP!_!RANDOM_SUFFIX!"
set "PROFILE_DIR=%TEMP%\!UNIQUE_PROFILE_ID!"

echo        ID профиля: !UNIQUE_PROFILE_ID!
echo        Путь:       !PROFILE_DIR!
if not exist "!PROFILE_DIR!" mkdir "!PROFILE_DIR!" >nul 2>&1

echo %LOG_PREFIX% Запускаем изолированную сессию...
if defined SESSION_URL (
    echo        URL:      !SESSION_URL!
) else (
    echo        URL:      (не задан, стартовая вкладка Chrome)
)
echo        Профиль: !PROFILE_DIR!
echo        Chrome:   !CHROME_EXE!
if defined SESSION_URL (
    start "" "!CHROME_EXE!" --new-window --user-data-dir="!PROFILE_DIR!" "!SESSION_URL!"
) else (
    start "" "!CHROME_EXE!" --new-window --user-data-dir="!PROFILE_DIR!"
)
echo %LOG_PREFIX% Сессия запущена. Профиль будет удалён после закрытия Chrome.
echo --------------------------------------------------
echo   Инструкция:
echo     • Работайте в открывшемся окне Chrome.
echo     • Закройте окно, чтобы удалить временный профиль.
echo --------------------------------------------------
echo.
if defined SESSION_URL (
    call :log_recent_url "quick" "!SESSION_URL!"
)
call :wait_for_key
goto :main_menu

:create_profile
cls
echo %LOG_PREFIX% Создание постоянного профиля
echo.
set "PROFILE_SLUG="
set /p "PROFILE_SLUG=Имя профиля (латиница, без пробелов): "
set "PROFILE_SLUG=!PROFILE_SLUG: =_!"
if not defined PROFILE_SLUG (
    echo %LOG_PREFIX% [Ошибка] Имя профиля не может быть пустым.
    call :wait_for_key
    goto :main_menu
)
set "PROFILE_PATH=%PROFILE_STORE%\!PROFILE_SLUG!"
if exist "!PROFILE_PATH!" (
    echo %LOG_PREFIX% [Ошибка] Профиль с таким именем уже существует.
    call :wait_for_key
    goto :main_menu
)
mkdir "!PROFILE_PATH!\data" >nul 2>&1

call :obtain_url PROFILE_SITE ""

> "!PROFILE_PATH!\profile.cfg" (
    echo NAME=!PROFILE_SLUG!
    echo SITE=!PROFILE_SITE!
    echo CREATED=%DATE% %TIME%
)

echo %LOG_PREFIX% [OK] Профиль "!PROFILE_SLUG!" создан.
call :wait_for_key
goto :main_menu

:launch_profile
cls
echo %LOG_PREFIX% Запуск сохранённого профиля
call :list_profiles_with_cache
if !PROFILE_COUNT! EQU 0 (
    call :wait_for_key
    goto :main_menu
)
set "PROFILE_SELECTION="
set /p "PROFILE_SELECTION=Введите номер профиля (0 = назад): "
if "%PROFILE_SELECTION%"=="0" goto :main_menu
call :resolve_profile_selection "!PROFILE_SELECTION!" SELECTED_PROFILE
if errorlevel 1 (
    call :wait_for_key
    goto :main_menu
)
call :load_profile_config "!SELECTED_PROFILE!\profile.cfg" PROFILE_SELECTED_NAME PROFILE_SELECTED_SITE
call :obtain_url TARGET_URL "!PROFILE_SELECTED_SITE!"

call :find_chrome
if not defined CHROME_EXE (
    echo %LOG_PREFIX% [Ошибка] Chrome не найден. Установите браузер.
    call :wait_for_key
    goto :main_menu
)
set "PROFILE_DATA_DIR=!SELECTED_PROFILE!\data"
if not exist "!PROFILE_DATA_DIR!" mkdir "!PROFILE_DATA_DIR!" >nul 2>&1

echo %LOG_PREFIX% Запускаем профиль "!PROFILE_SELECTED_NAME!"...
if defined TARGET_URL (
    start "" "!CHROME_EXE!" --new-window --user-data-dir="!PROFILE_DATA_DIR!" "!TARGET_URL!"
    call :log_recent_url "!PROFILE_SELECTED_NAME!" "!TARGET_URL!"
    call :offer_save_url "!TARGET_URL!"
) else (
    start "" "!CHROME_EXE!" --new-window --user-data-dir="!PROFILE_DATA_DIR!"
)
echo        Chrome запущен в отдельном окне.
call :wait_for_key
goto :main_menu

:delete_profile
cls
echo %LOG_PREFIX% Управление профилем
call :list_profiles_with_cache
if !PROFILE_COUNT! EQU 0 (
    call :wait_for_key
    goto :main_menu
)
set "PROFILE_SELECTION="
set /p "PROFILE_SELECTION=Введите номер профиля (0 = назад): "
if "%PROFILE_SELECTION%"=="0" goto :main_menu
call :resolve_profile_selection "!PROFILE_SELECTION!" SELECTED_PROFILE
if errorlevel 1 (
    call :wait_for_key
    goto :main_menu
)
call :load_profile_config "!SELECTED_PROFILE!\profile.cfg" PROFILE_SELECTED_NAME PROFILE_SELECTED_SITE
echo.
echo Выберите действие для профиля "!PROFILE_SELECTED_NAME!":
echo   1. Полностью удалить профиль
echo   2. Очистить только данные браузера
set "PROFILE_ACTION="
set /p "PROFILE_ACTION=Ваш выбор: "
if "%PROFILE_ACTION%"=="2" goto :clear_profile_data
if not "%PROFILE_ACTION%"=="1" (
    echo %LOG_PREFIX% Действие отменено.
    call :wait_for_key
    goto :main_menu
)
echo Вы уверены, что хотите удалить профиль? (Y/N)
choice /c YN /n >nul
if errorlevel 2 (
    echo %LOG_PREFIX% Удаление отменено.
    call :wait_for_key
    goto :main_menu
)
rmdir /s /q "!SELECTED_PROFILE!" >nul 2>&1
if exist "!SELECTED_PROFILE!" (
    echo %LOG_PREFIX% [Ошибка] Не удалось удалить профиль.
) else (
    echo %LOG_PREFIX% [OK] Профиль удалён.
)
call :wait_for_key
goto :main_menu

:clear_profile_data
set "PROFILE_DATA_DIR=!SELECTED_PROFILE!\data"
if exist "!PROFILE_DATA_DIR!" (
    rmdir /s /q "!PROFILE_DATA_DIR!" >nul 2>&1
)
mkdir "!PROFILE_DATA_DIR!" >nul 2>&1
echo %LOG_PREFIX% [OK] Данные Chrome для профиля очищены.
call :wait_for_key
goto :main_menu

:show_profiles
cls
echo %LOG_PREFIX% Доступные профили
call :list_profiles_with_cache
call :wait_for_key
goto :main_menu

:bookmarks_menu
cls
echo %LOG_PREFIX% Управление закладками
echo --------------------------------------------------
echo   1. Показать закладки
echo   2. Добавить закладку вручную
echo   3. Удалить закладку
echo   0. Назад
echo --------------------------------------------------
set "BOOKMARK_CHOICE="
set /p "BOOKMARK_CHOICE=Ваш выбор: "
if "%BOOKMARK_CHOICE%"=="1" (
    call :list_bookmarks
    call :wait_for_key
    goto :bookmarks_menu
)
if "%BOOKMARK_CHOICE%"=="2" (
    call :add_bookmark
    goto :bookmarks_menu
)
if "%BOOKMARK_CHOICE%"=="3" (
    call :delete_bookmark
    goto :bookmarks_menu
)
if "%BOOKMARK_CHOICE%"=="0" goto :main_menu
echo %LOG_PREFIX% [Ошибка] Неизвестный пункт меню.
call :wait_for_key
goto :bookmarks_menu

:theme_menu
cls
echo %LOG_PREFIX% Настройки темы интерфейса
echo --------------------------------------------------
echo   Текущая тема: !CURRENT_THEME_DESC!
echo --------------------------------------------------
echo   1. Тёмная — чёрный фон, бирюзовый текст
echo   2. Светлая — белый фон, чёрный текст
echo   3. Неоновая — чёрный фон, жёлтый текст
echo   0. Назад
echo --------------------------------------------------
set "THEME_CHOICE="
set /p "THEME_CHOICE=Ваш выбор: "
if "%THEME_CHOICE%"=="1" (
    call :apply_and_save_theme dark
    goto :theme_menu
)
if "%THEME_CHOICE%"=="2" (
    call :apply_and_save_theme light
    goto :theme_menu
)
if "%THEME_CHOICE%"=="3" (
    call :apply_and_save_theme neon
    goto :theme_menu
)
if "%THEME_CHOICE%"=="0" goto :main_menu
echo %LOG_PREFIX% [Ошибка] Неизвестный пункт меню.
call :wait_for_key
goto :theme_menu

:list_bookmarks
set "BOOKMARK_COUNT=0"
for /f "usebackq eol=# tokens=1,2 delims=|" %%I in ("%BOOKMARKS_FILE%") do (
    set "NAME=%%I"
    set "URL=%%J"
    if not "!NAME!"=="" if not "!URL!"=="" (
        set /a BOOKMARK_COUNT+=1
        echo   !BOOKMARK_COUNT!. !NAME!  [!URL!]
    )
)
if !BOOKMARK_COUNT! EQU 0 (
    echo   (закладок пока нет)
    exit /b 1
)
exit /b 0

:add_bookmark
cls
echo %LOG_PREFIX% Добавление закладки
set "BOOKMARK_TITLE="
set /p "BOOKMARK_TITLE=Название (Enter = URL): "
call :create_bookmark_interactive "%BOOKMARK_TITLE%" ""
call :wait_for_key
exit /b 0

:add_bookmark_quick
call :create_bookmark_interactive "" ""
exit /b 0

:create_bookmark_interactive
set "BOOKMARK_FLOW_TITLE=%~1"
set "BOOKMARK_FLOW_URL=%~2"
if "%BOOKMARK_FLOW_TITLE%"=="" set /p "BOOKMARK_FLOW_TITLE=Название (Enter = URL): "
set /p "BOOKMARK_FLOW_URL=URL (обязательно): "
if not defined BOOKMARK_FLOW_URL (
    echo %LOG_PREFIX% [Ошибка] URL не задан.
    exit /b 1
)
if not defined BOOKMARK_FLOW_TITLE set "BOOKMARK_FLOW_TITLE=%BOOKMARK_FLOW_URL%"
call :save_bookmark "%BOOKMARK_FLOW_TITLE%" "%BOOKMARK_FLOW_URL%"
echo %LOG_PREFIX% [OK] Закладка сохранена.
exit /b 0

:delete_bookmark
cls
echo %LOG_PREFIX% Удаление закладки
call :load_bookmark_cache_simple
if !BOOKMARK_COUNT! EQU 0 (
    echo   (закладок нет)
    call :wait_for_key
    exit /b 0
)
call :list_bookmarks
set "BOOKMARK_SELECTION="
set /p "BOOKMARK_SELECTION=Введите номер закладки: "
call :resolve_bookmark_selection "!BOOKMARK_SELECTION!" BOOKMARK_INDEX
if errorlevel 1 (
    call :wait_for_key
    exit /b 0
)
set "BOOKMARK_TMP=%QUICK_STORE%\bookmarks.tmp"
if exist "%BOOKMARK_TMP%" del "%BOOKMARK_TMP%" >nul 2>&1
set "BOOKMARK_LINE=0"
for /f "usebackq tokens=1,2 delims=|" %%I in ("%BOOKMARKS_FILE%") do (
    set /a BOOKMARK_LINE+=1
    if not "!BOOKMARK_LINE!"=="%BOOKMARK_INDEX%" (
        >> "%BOOKMARK_TMP%" echo %%I^|%%J
    )
)
move /y "%BOOKMARK_TMP%" "%BOOKMARKS_FILE%" >nul
echo %LOG_PREFIX% [OK] Закладка удалена.
call :wait_for_key
exit /b 0

:select_bookmark_url
set "BOOKMARK_RESULT=%~1"
set "%BOOKMARK_RESULT%="
call :load_bookmark_cache_simple
set "BOOKMARK_TOTAL=!BOOKMARK_COUNT!"
if not defined BOOKMARK_TOTAL goto :select_bookmark_no_entries
for /f "tokens=* delims= " %%Q in ("!BOOKMARK_TOTAL!") do set "BOOKMARK_TOTAL=%%Q"
if "!BOOKMARK_TOTAL!"=="0" goto :select_bookmark_no_entries

:select_bookmark_show_menu
echo --------------------------------------------------
echo Выберите закладку:
for /l %%N in (1,1,!BOOKMARK_COUNT!) do (
    for %%T in ("!BOOKMARK_NAME_%%N!") do for %%U in ("!BOOKMARK_URL_%%N!") do (
        echo   %%N. %%~T  [%%~U]
    )
)
echo   0. Вернуться назад
echo --------------------------------------------------
set "BOOKMARK_SELECTION="
set /p "BOOKMARK_SELECTION=Номер закладки: "
if not defined BOOKMARK_SELECTION goto :select_bookmark_show_menu
if "%BOOKMARK_SELECTION%"=="0" exit /b 1
echo.%BOOKMARK_SELECTION%| findstr /R "^[0-9][0-9]*$" >nul || (
    echo %LOG_PREFIX% [Ошибка] Введите корректный номер.
    goto :select_bookmark_show_menu
)
if %BOOKMARK_SELECTION% LEQ 0 goto :select_bookmark_show_menu
if %BOOKMARK_SELECTION% GTR %BOOKMARK_COUNT% (
    echo %LOG_PREFIX% [Ошибка] Закладка с таким номером отсутствует.
    goto :select_bookmark_show_menu
)
for %%P in ("!BOOKMARK_URL_%BOOKMARK_SELECTION%!") do set "%BOOKMARK_RESULT%=%%~P"
exit /b 0

:select_bookmark_no_entries
echo %LOG_PREFIX% Закладки отсутствуют.
echo Создать новую закладку сейчас? (Y/N)
choice /c YN /n >nul
if errorlevel 2 exit /b 1
call :add_bookmark_quick
call :load_bookmark_cache_simple
if !BOOKMARK_COUNT! EQU 0 exit /b 1
goto :select_bookmark_show_menu

:apply_and_save_theme
set "TARGET_THEME=%~1"
if not defined TARGET_THEME set "TARGET_THEME=%DEFAULT_THEME_ID%"
call :apply_theme "%TARGET_THEME%"
call :save_theme_config "%CURRENT_THEME_ID%"
echo %LOG_PREFIX% [OK] Тема переключена на "!CURRENT_THEME_DESC!".
timeout /t 1 >nul
exit /b 0

:select_recent_url
set "RECENT_RESULT=%~1"
set "%RECENT_RESULT%="
call :load_recent_cache
if !RECENT_COUNT! EQU 0 (
    echo %LOG_PREFIX% Недавних адресов нет.
    exit /b 1
)
echo --------------------------------------------------
for /l %%N in (1,1,!RECENT_COUNT!) do (
    for %%T in ("!RECENT_TIME_%%N!") do for %%P in ("!RECENT_PROFILE_%%N!") do for %%U in ("!RECENT_URL_%%N!") do (
        echo   %%N. %%~T  [%%~P]  %%~U
    )
)
set "RECENT_SELECTION="
set /p "RECENT_SELECTION=Номер URL: "
call :resolve_recent_selection "!RECENT_SELECTION!" RECENT_INDEX
if errorlevel 1 exit /b 1
for %%U in ("!RECENT_URL_%RECENT_INDEX%!") do set "%RECENT_RESULT%=%%~U"
exit /b 0

:load_theme_config
set "CURRENT_THEME_ID="
if exist "%THEME_CONFIG%" (
    for /f "usebackq tokens=1* delims==" %%I in ("%THEME_CONFIG%") do (
        if /i "%%~I"=="THEME_ID" set "CURRENT_THEME_ID=%%~J"
    )
)
if not defined CURRENT_THEME_ID set "CURRENT_THEME_ID=%DEFAULT_THEME_ID%"
exit /b 0

:save_theme_config
set "SAVE_THEME_ID=%~1"
if not defined SAVE_THEME_ID set "SAVE_THEME_ID=%DEFAULT_THEME_ID%"
> "%THEME_CONFIG%" (
    echo THEME_ID=%SAVE_THEME_ID%
)
exit /b 0

:ensure_theme_config
if not exist "%QUICK_STORE%" mkdir "%QUICK_STORE%" >nul 2>&1
if not exist "%THEME_CONFIG%" (
    call :save_theme_config "%DEFAULT_THEME_ID%"
)
exit /b 0

:apply_theme
set "REQUESTED_THEME=%~1"
if not defined REQUESTED_THEME set "REQUESTED_THEME=%DEFAULT_THEME_ID%"
if /i "%REQUESTED_THEME%"=="dark" (
    set "CURRENT_THEME_ID=dark"
    set "CURRENT_THEME_DESC=Тёмная — чёрный фон, бирюзовый текст"
    color 0B
    exit /b 0
)
if /i "%REQUESTED_THEME%"=="light" (
    set "CURRENT_THEME_ID=light"
    set "CURRENT_THEME_DESC=Светлая — белый фон, чёрный текст"
    color F0
    exit /b 0
)
if /i "%REQUESTED_THEME%"=="neon" (
    set "CURRENT_THEME_ID=neon"
    set "CURRENT_THEME_DESC=Неоновая — чёрный фон, жёлтый текст"
    color 0E
    exit /b 0
)
if /i not "%REQUESTED_THEME%"=="%DEFAULT_THEME_ID%" (
    call :apply_theme "%DEFAULT_THEME_ID%"
) else (
    set "CURRENT_THEME_ID=%DEFAULT_THEME_ID%"
    set "CURRENT_THEME_DESC=Тёмная — чёрный фон, бирюзовый текст"
    color 0B
)
exit /b 0

:list_profiles_with_cache
call :reset_profile_cache
if not exist "%PROFILE_STORE%" mkdir "%PROFILE_STORE%" >nul 2>&1
set "PROFILE_COUNT=0"
for /d %%D in ("%PROFILE_STORE%\*") do (
    if /i "%%~nD"=="_quick" (
        rem пропускаем служебную папку
    ) else (
        set /a PROFILE_COUNT+=1
        set "PROFILE_PATH_!PROFILE_COUNT!=%%~fD"
        call :load_profile_config "%%~fD\profile.cfg" PROFILE_TMP_NAME PROFILE_TMP_SITE
        if not defined PROFILE_TMP_NAME set "PROFILE_TMP_NAME=%%~nD"
        if not defined PROFILE_TMP_SITE set "PROFILE_TMP_SITE=URL не задан"
        echo   !PROFILE_COUNT!. !PROFILE_TMP_NAME!  [!PROFILE_TMP_SITE!]
    )
)
if !PROFILE_COUNT! EQU 0 (
    echo   (пока нет сохранённых профилей)
) else (
    echo   0. Вернуться назад
)
exit /b 0

:reset_profile_cache
for /f "tokens=1 delims==" %%V in ('set PROFILE_PATH_ 2^>nul') do set "%%V="
set "PROFILE_COUNT=0"
exit /b 0

:resolve_profile_selection
set "SELECTION=%~1"
set "%2="
if not defined SELECTION (
    echo %LOG_PREFIX% [Ошибка] Номер профиля не указан.
echo.%SELECTION%| findstr /R "^[0-9][0-9]*$" >nul || (
    echo %LOG_PREFIX% [Ошибка] Введите корректное число.
    exit /b 1
)
for /f %%N in ('powershell -NoProfile -Command "if ((%SELECTION%) -ge 1) { Write-Output %SELECTION% }"') do set "SELECTION=%%N"
if "%SELECTION%"=="" (
    echo %LOG_PREFIX% [Ошибка] Неверный номер.
    exit /b 1
)
if %SELECTION% GTR %PROFILE_COUNT% (
    echo %LOG_PREFIX% [Ошибка] Профиль под таким номером отсутствует.
    exit /b 1
)
for %%P in ("!PROFILE_PATH_%SELECTION%!") do set "%2=%%~fP"
exit /b 0

:load_profile_config
set "CFG_FILE=%~1"
set "TARGET_NAME=%~2"
set "TARGET_SITE=%~3"
set "%TARGET_NAME%="
set "%TARGET_SITE%="
if exist "%CFG_FILE%" (
    for /f "usebackq tokens=1* delims==" %%I in ("%CFG_FILE%") do (
        if /i "%%I"=="NAME" set "%TARGET_NAME%=%%J"
        if /i "%%I"=="SITE" set "%TARGET_SITE%=%%J"
    )
)
if not defined %TARGET_NAME% set "%TARGET_NAME%=Unnamed"
exit /b 0

:obtain_url
set "OB_TARGET=%~1"
set "OB_DEFAULT=%~2"
if not defined OB_TARGET exit /b 1
set "OB_CHOICE="
:obtain_url_prompt
echo --------------------------------------------------
echo Выберите источник URL:
echo   1. Ввести вручную
echo   2. Выбрать из закладок
echo   3. Выбрать из последних запусков
echo   0. Не указывать URL
if defined OB_DEFAULT (
    echo   [По умолчанию: !OB_DEFAULT!]
)
set /p "OB_CHOICE=Ваш выбор: "
if "%OB_CHOICE%"=="1" goto :obtain_url_manual
if "%OB_CHOICE%"=="2" goto :obtain_url_bookmark
if "%OB_CHOICE%"=="3" goto :obtain_url_recent
if "%OB_CHOICE%"=="0" (
    set "%OB_TARGET%="
    exit /b 0
)
echo %LOG_PREFIX% [Ошибка] Неизвестный пункт меню.
goto :obtain_url_prompt

:obtain_url_manual
set "OB_INPUT="
if defined OB_DEFAULT (
    set /p "OB_INPUT=URL (Enter = !OB_DEFAULT!): "
) else (
    set /p "OB_INPUT=URL (можно оставить пустым): "
)
if not defined OB_INPUT (
    if defined OB_DEFAULT (
        set "%OB_TARGET%=%OB_DEFAULT%"
    ) else (
        set "%OB_TARGET%="
    )
) else (
    set "%OB_TARGET%=%OB_INPUT%"
)
exit /b 0

:obtain_url_bookmark
set "BOOKMARK_VALUE="
call :select_bookmark_url BOOKMARK_VALUE
if errorlevel 1 (
    echo %LOG_PREFIX% [Инфо] Закладка не выбрана.
    goto :obtain_url_prompt
)
set "%OB_TARGET%=%BOOKMARK_VALUE%"
exit /b 0

:obtain_url_recent
set "RECENT_VALUE="
call :select_recent_url RECENT_VALUE
if errorlevel 1 (
    echo %LOG_PREFIX% [Инфо] URL не выбран.
    goto :obtain_url_prompt
)
set "%OB_TARGET%=%RECENT_VALUE%"
exit /b 0

:offer_save_url
set "SAVE_URL=%~1"
if not defined SAVE_URL exit /b 0
echo.
echo Сохранить ссылку в закладки? (Y/N)
choice /c YN /n >nul
if errorlevel 2 exit /b 0
set "BOOKMARK_TITLE="
set /p "BOOKMARK_TITLE=Название (Enter = URL): "
if not defined BOOKMARK_TITLE set "BOOKMARK_TITLE=%SAVE_URL%"
>> "%BOOKMARKS_FILE%" echo %BOOKMARK_TITLE%^|%SAVE_URL%
echo %LOG_PREFIX% [OK] Закладка сохранена.
exit /b 0

:log_recent_url
set "REC_PROFILE=%~1"
set "REC_URL=%~2"
if not defined REC_URL exit /b 0
if not defined REC_PROFILE set "REC_PROFILE=anonymous"
call :generate_stamp
>> "%RECENT_LOG%" echo !STAMP!^|%REC_PROFILE%^|%REC_URL%
call :trim_recent_log
exit /b 0

:trim_recent_log
if not exist "%RECENT_LOG%" exit /b 0
for /f %%C in ('find /c /v "" ^< "%RECENT_LOG%"') do set "RECENT_TOTAL=%%C"
if not defined RECENT_TOTAL exit /b 0
if !RECENT_TOTAL! LEQ %MAX_RECENT% exit /b 0
set /a RECENT_SKIP=!RECENT_TOTAL!-%MAX_RECENT%
set /a RECENT_START=RECENT_SKIP+1
set "RECENT_TMP=%QUICK_STORE%\recent.tmp"
more +!RECENT_START! "%RECENT_LOG%" > "%RECENT_TMP%"
move /y "%RECENT_TMP%" "%RECENT_LOG%" >nul
exit /b 0

:save_bookmark
set "SAVE_NAME=%~1"
set "SAVE_URL=%~2"
if not defined SAVE_URL exit /b 1
if not defined SAVE_NAME set "SAVE_NAME=%SAVE_URL%"
>> "%BOOKMARKS_FILE%" echo %SAVE_NAME%^|%SAVE_URL%
exit /b 0

:load_bookmark_cache_simple
call :reset_bookmark_cache
if not exist "%BOOKMARKS_FILE%" exit /b 0
set "BOOKMARK_COUNT=0"
for /f "usebackq eol=# tokens=1* delims=|" %%I in ("%BOOKMARKS_FILE%") do (
    set "LINE_NAME=%%~I"
    set "LINE_URL=%%~J"
    if not "!LINE_NAME!"=="" if not "!LINE_URL!"=="" (
        set /a BOOKMARK_COUNT+=1
        set "BOOKMARK_NAME_!BOOKMARK_COUNT!=!LINE_NAME!"
        set "BOOKMARK_URL_!BOOKMARK_COUNT!=!LINE_URL!"
    )
)
exit /b 0

:reset_bookmark_cache
for /f "tokens=1 delims==" %%V in ('set BOOKMARK_NAME_ 2^>nul') do set "%%V="
for /f "tokens=1 delims==" %%V in ('set BOOKMARK_URL_ 2^>nul') do set "%%V="
set "BOOKMARK_COUNT=0"
exit /b 0

:resolve_bookmark_selection
set "BOOKMARK_SELECTION=%~1"
set "%2="
if not defined BOOKMARK_SELECTION (
    echo %LOG_PREFIX% [Ошибка] Номер не указан.
    exit /b 1
)
echo.%BOOKMARK_SELECTION%| findstr /R "^[0-9][0-9]*$" >nul || (
    echo %LOG_PREFIX% [Ошибка] Введите корректное число.
    exit /b 1
)
if %BOOKMARK_SELECTION% LSS 1 (
    echo %LOG_PREFIX% [Ошибка] Неверный номер.
    exit /b 1
)
if %BOOKMARK_SELECTION% GTR %BOOKMARK_COUNT% (
    echo %LOG_PREFIX% [Ошибка] Закладка с таким номером отсутствует.
    exit /b 1
)
set "%2=%BOOKMARK_SELECTION%"
exit /b 0

:load_recent_cache
call :reset_recent_cache
if not exist "%RECENT_LOG%" exit /b 0
for /f "usebackq tokens=1-3 delims=|" %%I in ("%RECENT_LOG%") do (
    set /a RECENT_COUNT+=1
    set "RECENT_TIME_!RECENT_COUNT!=%%I"
    set "RECENT_PROFILE_!RECENT_COUNT!=%%J"
    set "RECENT_URL_!RECENT_COUNT!=%%K"
)
exit /b 0

:reset_recent_cache
for /f "tokens=1 delims==" %%V in ('set RECENT_TIME_ 2^>nul') do set "%%V="
for /f "tokens=1 delims==" %%V in ('set RECENT_PROFILE_ 2^>nul') do set "%%V="
for /f "tokens=1 delims==" %%V in ('set RECENT_URL_ 2^>nul') do set "%%V="
set "RECENT_COUNT=0"
exit /b 0

:resolve_recent_selection
set "RECENT_SELECTION=%~1"
set "%2="
if not defined RECENT_SELECTION (
    echo %LOG_PREFIX% [Ошибка] Номер не указан.
    exit /b 1
)
echo.%RECENT_SELECTION%| findstr /R "^[0-9][0-9]*$" >nul || (
    echo %LOG_PREFIX% [Ошибка] Введите корректное число.
    exit /b 1
)
if %RECENT_SELECTION% LSS 1 (
    echo %LOG_PREFIX% [Ошибка] Неверный номер.
    exit /b 1
)
if %RECENT_SELECTION% GTR %RECENT_COUNT% (
    echo %LOG_PREFIX% [Ошибка] Элемент с таким номером отсутствует.
    exit /b 1
)
set "%2=%RECENT_SELECTION%"
exit /b 0

:ensure_profile_store
if not exist "%PROFILE_STORE%" mkdir "%PROFILE_STORE%" >nul 2>&1
exit /b 0

:ensure_quick_store
if not exist "%QUICK_STORE%" mkdir "%QUICK_STORE%" >nul 2>&1
exit /b 0

:ensure_bookmarks_file
if not exist "%BOOKMARKS_FILE%" type nul > "%BOOKMARKS_FILE%"
exit /b 0

:ensure_recent_log
if not exist "%QUICK_STORE%" mkdir "%QUICK_STORE%" >nul 2>&1
if not exist "%RECENT_LOG%" type nul > "%RECENT_LOG%"
exit /b 0

:wait_for_key
echo.
pause
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
exit /b 0

:exit_success
echo %LOG_PREFIX% Работа завершена.
call :restore_codepage
endlocal
exit /b 0

:configure_codepage
set "ORIGINAL_CP="
for /f "tokens=2 delims=:" %%I in ('chcp ^| find ":"') do (
    set "ORIGINAL_CP=%%I"
)
for /f "tokens=1 delims=. " %%I in ("!ORIGINAL_CP!") do set "ORIGINAL_CP=%%I"
set "ORIGINAL_CP=!ORIGINAL_CP: =!"
if defined ORIGINAL_CP (
    if not "!ORIGINAL_CP!"=="65001" (
        chcp 65001 >nul
    ) else (
        set "ORIGINAL_CP="
    )
)
exit /b 0

:restore_codepage
if defined ORIGINAL_CP (
    chcp !ORIGINAL_CP! >nul
)
exit /b 0


:ensure_worker_store
if not exist "%WORKER_STORE%" mkdir "%WORKER_STORE%" >nul 2>&1
exit /b 0

:launch_quick_session_worker
set "WRK_PROFILE_ID=%~1"
set "WRK_PROFILE_DIR=%~2"
set "WRK_SESSION_URL=%~3"
call :generate_stamp
set "WRK_ID=!STAMP!_!RANDOM!"
set "WRK_FILE=%WORKER_STORE%\!WRK_ID!.tmp"
echo %LOG_PREFIX% [DEBUG] Создаю воркер-файл: !WRK_FILE!
(
    echo set "PROFILE_ID=%WRK_PROFILE_ID%"
    echo set "PROFILE_DIR=%WRK_PROFILE_DIR%"
    echo set "SESSION_URL=%WRK_SESSION_URL%"
    echo set "CHROME_EXE=%CHROME_EXE%"
    echo set "LOG_PREFIX=%LOG_PREFIX%"
) > "!WRK_FILE!"
echo %LOG_PREFIX% [DEBUG] Воркер-файл создан, содержимое:
type "!WRK_FILE!"
echo %LOG_PREFIX% [DEBUG] Запускаю воркер: cmd /c "%SCRIPT_PATH%" --worker "!WRK_ID!"
start "" cmd /c "%SCRIPT_PATH%" --worker "!WRK_ID!"
echo %LOG_PREFIX% [DEBUG] Воркер запущен
exit /b 0

:quick_session_worker_entry
setlocal EnableExtensions EnableDelayedExpansion
set "WRK_ID=%~1"
set "WRK_FILE=%WORKER_STORE%\!WRK_ID!.tmp"
echo %LOG_PREFIX% [WORKER] Воркер запущен, ID=!WRK_ID!
echo %LOG_PREFIX% [WORKER] Ищу воркер-файл: !WRK_FILE!
if not exist "!WRK_FILE!" (
    echo %LOG_PREFIX% [WORKER] [Ошибка] Воркер-файл не найден!
    exit /b 1
)
echo %LOG_PREFIX% [WORKER] Загружаю параметры из воркер-файла...
call "!WRK_FILE!" >nul 2>&1
echo %LOG_PREFIX% [WORKER] Параметры загружены:
echo %LOG_PREFIX% [WORKER] PROFILE_ID=!PROFILE_ID!
echo %LOG_PREFIX% [WORKER] PROFILE_DIR=!PROFILE_DIR!
echo %LOG_PREFIX% [WORKER] SESSION_URL=!SESSION_URL!
echo %LOG_PREFIX% [WORKER] CHROME_EXE=!CHROME_EXE!
del "!WRK_FILE!" >nul 2>&1

if not exist "!PROFILE_DIR!" (
    echo %LOG_PREFIX% [WORKER] Создаю директорию профиля: !PROFILE_DIR!
    mkdir "!PROFILE_DIR!" >nul 2>&1
)
echo %LOG_PREFIX% [WORKER] Проверяю существование Chrome: !CHROME_EXE!
if not exist "!CHROME_EXE!" (
    echo %LOG_PREFIX% [WORKER] [Ошибка] Chrome не найден: !CHROME_EXE!
    exit /b 1
)
if defined SESSION_URL (
    echo %LOG_PREFIX% [WORKER] Запускаю Chrome с URL=!SESSION_URL!
    echo %LOG_PREFIX% [WORKER] Команда: start "" "!CHROME_EXE!" --new-window --user-data-dir="!PROFILE_DIR!" "!SESSION_URL!"
    start "" "!CHROME_EXE!" --new-window --user-data-dir="!PROFILE_DIR!" "!SESSION_URL!"
) else (
    echo %LOG_PREFIX% [WORKER] Запускаю Chrome без URL
    echo %LOG_PREFIX% [WORKER] Команда: start "" "!CHROME_EXE!" --new-window --user-data-dir="!PROFILE_DIR!"
    start "" "!CHROME_EXE!" --new-window --user-data-dir="!PROFILE_DIR!"
)
echo %LOG_PREFIX% [WORKER] Команда запуска Chrome выполнена
echo %LOG_PREFIX% [WORKER] Ожидание 3 секунды для проверки запуска...
timeout /t 3 >nul
echo %LOG_PREFIX% [WORKER] Воркер завершает работу
exit /b 0

:process_completed_workers
for %%F in ("%WORKER_STORE%\*.tmp") do (
    set "WRK_PATH=%%~fF"
    for /f "tokens=*" %%L in ("%%~fF") do (
        for /f "tokens=2 delims==" %%V in ("%%L") do (
            if /i "%%V"=="PROFILE_DIR" (
                for /f "tokens=2 delims==" %%D in ("%%L") do set "CHECK_DIR=%%~D"
                if not exist "!CHECK_DIR!" (
                    del "%%~fF" >nul 2>&1
                )
            )
        )
    )
)
exit /b 0
