# CarApp — минимальный рабочий прототип

## 1. База данных (PostgreSQL 17)
```
psql -U postgres -c "CREATE DATABASE carapp;"
psql -U postgres -d carapp -f db/01_schema.sql
psql -U postgres -d carapp -f db/02_seed.sql
```

## 2. Бэкенд (Python 3.10+)
```
cd backend
python -m venv venv && venv\Scripts\activate      # Windows
pip install -r requirements.txt
set DB_DSN=postgresql://postgres:ВАШ_ПАРОЛЬ@localhost:5432/carapp
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```
Проверка: http://localhost:8000/docs

## 3. Android
1. Android Studio → New Project → **Empty Activity** (Compose), package `com.example.carapp`, minSdk 26.
2. В своём `AndroidManifest.xml` оставьте тему из шаблона, но добавьте `<uses-permission android:name="android.permission.INTERNET"/>` и `android:usesCleartextTraffic="true"` в `<application>`. Добавьте/замените файлы `Api.kt`, `MainActivity.kt`, `Screens.kt` из `android/app/src/main/...`.
3. Добавьте зависимости из `android/dependencies.txt`.
4. Запустите бэкенд, затем приложение на эмуляторе (адрес 10.0.2.2 = ПК). Для телефона поменяйте `BASE_URL` в `Api.kt` на IP ПК.
