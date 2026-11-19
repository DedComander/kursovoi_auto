@echo off
chcp 65001 >nul
echo Запрашиваю http://localhost:8000/listings ...
powershell -NoProfile -Command "try { $r = Invoke-RestMethod http://localhost:8000/listings; Write-Host ('Получено объявлений: ' + @($r).Count + ' (ожидается 5)') } catch { Write-Host ('Ошибка: ' + $_.Exception.Message) }"
pause
