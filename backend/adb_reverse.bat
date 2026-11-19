@echo off
chcp 65001 >nul
set "ADB=C:\Users\user\AppData\Local\Android\Sdk\platform-tools\adb.exe"
if not exist "%ADB%" (
    echo Не найден adb: %ADB%
    echo Исправьте путь в первой строке файла ^(Android Studio: Settings - Android SDK - Android SDK Location^).
    pause & exit /b 1
)
"%ADB%" devices
echo.
"%ADB%" reverse tcp:8000 tcp:8000
if errorlevel 1 (
    echo Не удалось пробросить порт. Убедитесь, что эмулятор полностью загрузился ^(виден рабочий стол Android^).
    pause & exit /b 1
)
echo.
echo Текущие пробросы:
"%ADB%" reverse --list
echo.
echo Готово. Теперь в приложении нажмите "Найти". Сервер ^(run_backend.bat^) должен быть запущен.
pause
