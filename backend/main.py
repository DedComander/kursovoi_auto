import hashlib, hmac, os, json, time
from datetime import datetime, timedelta, timezone
from typing import Optional

import jwt
import psycopg
from psycopg.rows import dict_row
from fastapi import FastAPI, Depends, HTTPException, Header, Response
from pydantic import BaseModel

DB_DSN = os.getenv("DB_DSN", "postgresql://postgres:postgres@localhost:5432/carapp")
JWT_SECRET = os.getenv("JWT_SECRET", "change-me-in-prod")

app = FastAPI(title="CarApp API")


def db():
    with psycopg.connect(DB_DSN, row_factory=dict_row) as conn:
        yield conn


# ---------- auth ----------
def hash_pw(pw: str, salt: Optional[bytes] = None) -> str:
    salt = salt or os.urandom(16)
    h = hashlib.pbkdf2_hmac("sha256", pw.encode(), salt, 200_000)
    return salt.hex() + ":" + h.hex()


def check_pw(pw: str, stored: str) -> bool:
    salt_hex, h_hex = stored.split(":")
    return hmac.compare_digest(hash_pw(pw, bytes.fromhex(salt_hex)), stored)


def make_token(user_id: int) -> str:
    exp = datetime.now(timezone.utc) + timedelta(days=7)
    return jwt.encode({"sub": str(user_id), "exp": exp}, JWT_SECRET, algorithm="HS256")


def current_user(authorization: Optional[str] = Header(None)) -> int:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "Требуется авторизация")
    try:
        data = jwt.decode(authorization[7:], JWT_SECRET, algorithms=["HS256"])
        return int(data["sub"])
    except Exception:
        raise HTTPException(401, "Неверный токен")


class Creds(BaseModel):
    email: str
    password: str
    name: Optional[str] = None


@app.post("/auth/register")
def register(c: Creds, conn=Depends(db)):
    if len(c.password) < 6:
        raise HTTPException(400, "Пароль минимум 6 символов")
    if conn.execute("SELECT 1 FROM app_user WHERE email=%s", (c.email,)).fetchone():
        raise HTTPException(409, "Email уже занят")
    row = conn.execute(
        "INSERT INTO app_user (email,password_hash,name) VALUES (%s,%s,%s) RETURNING id",
        (c.email, hash_pw(c.password), c.name)).fetchone()
    return {"token": make_token(row["id"]), "email": c.email}


@app.post("/auth/login")
def login(c: Creds, conn=Depends(db)):
    u = conn.execute("SELECT id,password_hash FROM app_user WHERE email=%s", (c.email,)).fetchone()
    if not u or not check_pw(c.password, u["password_hash"]):
        raise HTTPException(401, "Неверный email или пароль")
    return {"token": make_token(u["id"]), "email": c.email}


# ---------- listings ----------
LIST_COLS = """l.id, l.brand, l.model, l.year, l.mileage, l.price::float AS price, l.city,
  l.transmission, l.fuel_type, l.body_type, l.reliability_rating::float AS reliability_rating,
  (SELECT url FROM listing_photo p WHERE p.listing_id=l.id ORDER BY sort_order LIMIT 1) AS photo"""


@app.get("/listings")
def search(brand: Optional[str] = None, model: Optional[str] = None,
           year_from: Optional[int] = None, year_to: Optional[int] = None,
           price_from: Optional[float] = None, price_to: Optional[float] = None,
           mileage_from: Optional[int] = None, mileage_to: Optional[int] = None,
           body_type: Optional[str] = None, transmission: Optional[str] = None,
           fuel_type: Optional[str] = None, city: Optional[str] = None,
           conn=Depends(db)):
    where, args = ["l.is_active"], []

    def add(cond, val):
        if val is not None and val != "":
            where.append(cond); args.append(val)

    add("l.brand ILIKE %s", brand and f"%{brand}%")
    add("l.model ILIKE %s", model and f"%{model}%")
    add("l.year >= %s", year_from); add("l.year <= %s", year_to)
    add("l.price >= %s", price_from); add("l.price <= %s", price_to)
    add("l.mileage >= %s", mileage_from); add("l.mileage <= %s", mileage_to)
    add("l.body_type = %s", body_type); add("l.transmission = %s", transmission)
    add("l.fuel_type = %s", fuel_type); add("l.city ILIKE %s", city and f"%{city}%")
    sql = f"SELECT {LIST_COLS} FROM listing l WHERE {' AND '.join(where)} ORDER BY l.published_date DESC LIMIT 100"
    return conn.execute(sql, args).fetchall()


def run_analysis(conn, listing: dict):
    """БП6-БП9. Вместо реального ИИ-агента — разбор справочника weakness.
    Точка расширения: здесь можно вызвать LLM и записать ответ в weakness / ai_analysis_log."""
    started = time.time()
    if not listing["car_model_id"]:
        conn.execute("UPDATE listing SET analysis_status='ERROR' WHERE id=%s", (listing["id"],))
        return
    engine_key = f"{listing['engine_volume']}"
    weaknesses = conn.execute(
        """SELECT * FROM weakness WHERE car_model_id=%s
           AND (engine_variant IS NULL OR engine_variant LIKE %s)""",
        (listing["car_model_id"], f"{engine_key}%")).fetchall()
    rating = 10.0
    penalty = {"CRITICAL": 2.0, "MODERATE": 1.0, "MINOR": 0.3}
    for w in weaknesses:
        tm = w["typical_mileage"] or 0
        relevant = listing["mileage"] >= tm * 0.7            # БП8
        note = (f"Пробег {listing['mileage']} км — проблема уже вероятна" if relevant
                else f"Пробег {listing['mileage']} км значительно ниже типичного ({tm} км)")
        conn.execute(
            """INSERT INTO listing_weakness (listing_id,weakness_id,is_relevant,relevance_note)
               VALUES (%s,%s,%s,%s) ON CONFLICT (listing_id,weakness_id) DO UPDATE
               SET is_relevant=EXCLUDED.is_relevant, relevance_note=EXCLUDED.relevance_note""",
            (listing["id"], w["id"], relevant, note))
        if relevant:
            rating -= penalty[w["severity"]]
    rating = max(1.0, round(rating, 1))
    conn.execute("UPDATE listing SET reliability_rating=%s, analysis_status='DONE' WHERE id=%s",
                 (rating, listing["id"]))
    conn.execute(
        "INSERT INTO ai_analysis_log (listing_id,car_model_id,request_text,response_text,status,duration_ms) "
        "VALUES (%s,%s,%s,%s,'SUCCESS',%s)",
        (listing["id"], listing["car_model_id"], "rule-based analysis",
         json.dumps({"rating": rating, "weaknesses": len(weaknesses)}),
         int((time.time() - started) * 1000)))


def load_details(conn, listing_id: int):
    l = conn.execute("SELECT * FROM listing WHERE id=%s", (listing_id,)).fetchone()
    if not l:
        raise HTTPException(404, "Объявление не найдено")
    if l["analysis_status"] != "DONE":
        run_analysis(conn, l)
        l = conn.execute("SELECT * FROM listing WHERE id=%s", (listing_id,)).fetchone()
    photos = conn.execute("SELECT url FROM listing_photo WHERE listing_id=%s ORDER BY sort_order",
                          (listing_id,)).fetchall()
    weak = conn.execute(
        """SELECT w.system_node, w.title, w.description, w.severity, w.typical_mileage,
                  w.repair_cost_min::float AS repair_cost_min, w.repair_cost_max::float AS repair_cost_max,
                  lw.is_relevant, lw.relevance_note
           FROM listing_weakness lw JOIN weakness w ON w.id=lw.weakness_id
           WHERE lw.listing_id=%s ORDER BY lw.is_relevant DESC, w.severity""", (listing_id,)).fetchall()
    for k in ("price", "engine_volume", "reliability_rating"):
        if l.get(k) is not None:
            l[k] = float(l[k])
    l["published_date"] = str(l["published_date"]); l["last_updated"] = str(l["last_updated"])
    l["photos"] = [p["url"] for p in photos]
    l["weaknesses"] = weak
    return l


@app.get("/listings/{listing_id}")
def details(listing_id: int, conn=Depends(db)):
    return load_details(conn, listing_id)


@app.post("/listings/{listing_id}/refresh")      # Ф3 / БП3 (заглушка парсера)
def refresh(listing_id: int, conn=Depends(db)):
    conn.execute("UPDATE listing SET last_updated=now() WHERE id=%s", (listing_id,))
    return load_details(conn, listing_id)


# ---------- photos (хранятся в БД, поле listing_photo.data) ----------
@app.get("/photos/{photo_id}")
def photo(photo_id: int, conn=Depends(db)):
    row = conn.execute("SELECT data, content_type FROM listing_photo WHERE id=%s", (photo_id,)).fetchone()
    if not row or row["data"] is None:
        raise HTTPException(404, "Фото не найдено")
    return Response(content=bytes(row["data"]), media_type=row["content_type"] or "image/jpeg",
                    headers={"Cache-Control": "public, max-age=86400"})


# ---------- favorites ----------
@app.get("/favorites")
def favorites(uid: int = Depends(current_user), conn=Depends(db)):
    return conn.execute(
        f"SELECT {LIST_COLS} FROM favorite f JOIN listing l ON l.id=f.listing_id "
        "WHERE f.user_id=%s ORDER BY f.added_at DESC", (uid,)).fetchall()


@app.post("/favorites/{listing_id}")
def add_fav(listing_id: int, uid: int = Depends(current_user), conn=Depends(db)):
    conn.execute("INSERT INTO favorite (user_id,listing_id) VALUES (%s,%s) ON CONFLICT DO NOTHING",
                 (uid, listing_id))
    return {"ok": True}


@app.delete("/favorites/{listing_id}")
def del_fav(listing_id: int, uid: int = Depends(current_user), conn=Depends(db)):
    conn.execute("DELETE FROM favorite WHERE user_id=%s AND listing_id=%s", (uid, listing_id))
    return {"ok": True}


# ---------- compare (Ф7, до 4) ----------
@app.get("/compare")
def compare(ids: str, uid: int = Depends(current_user), conn=Depends(db)):
    id_list = [int(x) for x in ids.split(",") if x][:4]
    return [load_details(conn, i) for i in id_list]


# ---------- saved searches (Ф8) ----------
class SavedSearchIn(BaseModel):
    name: str
    filters: dict
    notify_enabled: bool = True


@app.get("/saved-searches")
def saved_list(uid: int = Depends(current_user), conn=Depends(db)):
    return conn.execute("SELECT id,name,filters_json,notify_enabled FROM saved_search WHERE user_id=%s ORDER BY id DESC",
                        (uid,)).fetchall()


@app.post("/saved-searches")
def saved_add(s: SavedSearchIn, uid: int = Depends(current_user), conn=Depends(db)):
    row = conn.execute(
        "INSERT INTO saved_search (user_id,name,filters_json,notify_enabled) VALUES (%s,%s,%s,%s) RETURNING id",
        (uid, s.name, json.dumps(s.filters), s.notify_enabled)).fetchone()
    return row
