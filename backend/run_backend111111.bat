@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
cd /d "%~dp0"
title CarApp backend

rem ===== Настройки подключения к БД =====
set "DB_HOST=localhost"
set "DB_PORT=5432"
set "DB_NAME=carapp"
set "DB_USER=postgres"
set "PORT=8000"
set "CFG=.db_password"

rem Запуск с параметром reset забывает сохранённый пароль:  run_backend.bat reset
if /i "%~1"=="reset" (
    del "%CFG%" 2>nul
    echo Сохранённый пароль удалён.
)

rem ===== Пароль PostgreSQL =====
set "PGPASSWORD="
if exist "%CFG%" set /p PGPASSWORD=<"%CFG%"
if not defined PGPASSWORD (
    set /p "PGPASSWORD=Введите пароль PostgreSQL для пользователя %DB_USER%: "
    set /p "SAVE=Запомнить пароль? (y/n): "
    if /i "!SAVE!"=="y" (
        >"%CFG%" echo(!PGPASSWORD!
        echo Пароль сохранён в файле %CFG% ^(открытым текстом, не отправляйте его никому^).
    )
)

rem ===== Python и виртуальное окружение =====
set "PY="
where python >nul 2>&1 && set "PY=python"
if not defined PY ( where py >nul 2>&1 && set "PY=py" )
if not defined PY (
    echo Python не найден. Установите Python 3.10+ с python.org ^(галочка Add to PATH^).
    pause & exit /b 1
)
if not exist "venv\Scripts\python.exe" (
    echo Создаю виртуальное окружение...
    %PY% -m venv venv || ( echo Не удалось создать venv & pause & exit /b 1 )
)
if not exist "venv\.deps_installed" (
    echo Устанавливаю зависимости...
    "venv\Scripts\python.exe" -m pip install -r requirements.txt || ( echo Ошибка установки зависимостей & pause & exit /b 1 )
    echo ok>"venv\.deps_installed"
)

rem ===== Проверка подключения к БД =====
set "DB_DSN=host=%DB_HOST% port=%DB_PORT% dbname=%DB_NAME% user=%DB_USER%"
"venv\Scripts\python.exe" -c "import os,psycopg; psycopg.connect(os.environ['DB_DSN'], connect_timeout=5).close()" >nul 2>&1
if errorlevel 1 (
    echo.
    echo Не удалось подключиться к БД %DB_NAME% на %DB_HOST%:%DB_PORT%.
    echo Проверьте: запущен ли PostgreSQL, создана ли база %DB_NAME%, верен ли пароль.
    del "%CFG%" 2>nul
    echo Сохранённый пароль удалён - при следующем запуске введите его заново.
    pause & exit /b 1
)
echo Подключение к БД успешно.

rem ===== Открыть /docs в браузере через 4 секунды и запустить сервер =====
start "" powershell -NoProfile -WindowStyle Hidden -Command "Start-Sleep 4; Start-Process 'http://localhost:%PORT%/docs'"
echo Сервер: http://localhost:%PORT%/docs   ^(остановить: Ctrl+C^)
"venv\Scripts\python.exe" -m uvicorn main:app --host 0.0.0.0 --port %PORT% --reload
pause
