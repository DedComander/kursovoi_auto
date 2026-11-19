"""Подбирает реальные фото автомобилей из Wikimedia Commons и записывает их в listing_photo.
Запуск: update_photos.bat  (или: python update_photos.py при заданной DB_DSN)."""
import json, os, sys, urllib.parse, urllib.request
import psycopg

sys.stdout.reconfigure(encoding="utf-8")

API = "https://commons.wikimedia.org/w/api.php"
UA = "CarAppCourseProject/1.0 (student coursework; Wikimedia Commons API client)"
DB_DSN = os.getenv("DB_DSN", "host=localhost port=5432 dbname=carapp user=postgres")
PHOTOS_PER_LISTING = 3

# Поисковые запросы по моделям; для остальных используется "марка модель"
QUERIES = {
    ("Skoda", "Octavia"): "Škoda Octavia III",
    ("Toyota", "Camry"): "Toyota Camry XV70",
    ("Volkswagen", "Polo"): "Volkswagen Polo V sedan",
}
BAD_WORDS = ("interior", "innenraum", "dashboard", "cockpit", "logo", "badge", "emblem", "engine",
             "motor", "wheel", "seat", "detail", "blueprint", "drawing", "diagram", "museum",
             "rally", "race", "police", "taxi", "advert", "poster")


def search(query: str, limit: int = 40):
    params = {
        "action": "query", "format": "json", "generator": "search",
        "gsrsearch": f"{query} filetype:bitmap", "gsrnamespace": "6", "gsrlimit": str(limit),
        "prop": "imageinfo", "iiprop": "url|mime|size", "iiurlwidth": "800",
    }
    req = urllib.request.Request(API + "?" + urllib.parse.urlencode(params), headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.load(r)
    pages = sorted(data.get("query", {}).get("pages", {}).values(), key=lambda p: p.get("index", 0))
    urls = []
    for p in pages:
        title = p.get("title", "").lower()
        info = (p.get("imageinfo") or [{}])[0]
        if info.get("mime") != "image/jpeg" or any(w in title for w in BAD_WORDS):
            continue
        if info.get("width", 0) < info.get("height", 1):      # только горизонтальные кадры
            continue
        if info.get("thumburl"):
            urls.append(info["thumburl"])
    return urls


def main():
    cache, used = {}, {}
    with psycopg.connect(DB_DSN) as conn:
        rows = conn.execute("SELECT id, brand, model FROM listing ORDER BY id").fetchall()
        for lid, brand, model in rows:
            key = (brand, model)
            query = QUERIES.get(key, f"{brand} {model}")
            if key not in cache:
                try:
                    cache[key] = search(query)
                except Exception as e:
                    print(f"[!] Поиск '{query}' не удался: {e}")
                    cache[key] = []
                print(f"'{query}': найдено фото {len(cache[key])}")
            pics = cache[key]
            if not pics:
                print(f"  объявление {lid}: фото не найдены, оставляю как есть")
                continue
            n = used.get(key, 0)                  # разные объявления одной модели получают разные снимки
            used[key] = n + 1
            chosen = [pics[(n * PHOTOS_PER_LISTING + i) % len(pics)] for i in range(PHOTOS_PER_LISTING)]
            chosen = list(dict.fromkeys(chosen))
            conn.execute("DELETE FROM listing_photo WHERE listing_id=%s", (lid,))
            for order, url in enumerate(chosen):
                conn.execute("INSERT INTO listing_photo (listing_id, url, sort_order) VALUES (%s,%s,%s)",
                             (lid, url, order))
            print(f"  объявление {lid} ({brand} {model}): записано фото {len(chosen)}")
    print("Готово. Обновите список в приложении.")


if __name__ == "__main__":
    main()
