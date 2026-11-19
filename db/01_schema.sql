-- PostgreSQL 17. Запуск: psql -U postgres -d carapp -f 01_schema.sql
DROP TABLE IF EXISTS notification, saved_search, favorite, ai_analysis_log,
  listing_weakness, weakness, listing_photo, listing, car_model, source, app_user CASCADE;

CREATE TABLE app_user (            -- "User" зарезервировано в PG, поэтому app_user
  id            SERIAL PRIMARY KEY,
  email         VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  name          VARCHAR(100),
  fcm_token     VARCHAR(500),
  is_guest      BOOLEAN NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE source (
  id        SERIAL PRIMARY KEY,
  name      VARCHAR(50)  NOT NULL,
  base_url  VARCHAR(255) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE car_model (
  id        SERIAL PRIMARY KEY,
  brand     VARCHAR(100) NOT NULL,
  model     VARCHAR(100) NOT NULL,
  generation VARCHAR(50),
  year_from INT,
  year_to   INT,                   -- NULL = выпускается
  engines   JSONB NOT NULL DEFAULT '[]'
);

CREATE TABLE listing (
  id             SERIAL PRIMARY KEY,
  source_id      INT NOT NULL REFERENCES source(id),
  external_id    VARCHAR(255) NOT NULL,
  source_url     VARCHAR(1000) NOT NULL,
  car_model_id   INT REFERENCES car_model(id),
  brand          VARCHAR(100) NOT NULL,
  model          VARCHAR(100) NOT NULL,
  year           INT NOT NULL,
  mileage        INT NOT NULL,
  engine_volume  DECIMAL(3,1),
  engine_power   INT,
  fuel_type      VARCHAR(20),
  transmission   VARCHAR(20),
  drive_type     VARCHAR(10),
  body_type      VARCHAR(20),
  color          VARCHAR(30),
  owners_count   INT,
  vin            VARCHAR(17),
  condition      VARCHAR(20),
  trim_level     VARCHAR(200),
  price          DECIMAL(12,2) NOT NULL,
  currency       VARCHAR(3) NOT NULL DEFAULT 'RUB' CHECK (currency = 'RUB'),   -- БП14
  city           VARCHAR(100),
  description    TEXT,
  published_date DATE,
  last_updated   TIMESTAMP NOT NULL DEFAULT now(),
  is_active      BOOLEAN NOT NULL DEFAULT TRUE,
  reliability_rating DECIMAL(3,1) CHECK (reliability_rating BETWEEN 1.0 AND 10.0),
  analysis_status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
        CHECK (analysis_status IN ('PENDING','IN_PROGRESS','DONE','ERROR')),
  UNIQUE (source_id, external_id)                                              -- БП2 дедупликация
);
CREATE INDEX idx_listing_search ON listing (brand, model, year, price);

CREATE TABLE listing_photo (
  id         SERIAL PRIMARY KEY,
  listing_id INT NOT NULL REFERENCES listing(id) ON DELETE CASCADE,
  url        VARCHAR(1000) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0
);

CREATE TABLE weakness (
  id              SERIAL PRIMARY KEY,
  car_model_id    INT NOT NULL REFERENCES car_model(id) ON DELETE CASCADE,
  engine_variant  VARCHAR(50),                       -- NULL = для всех двигателей
  system_node     VARCHAR(50) NOT NULL
        CHECK (system_node IN ('ENGINE','TRANSMISSION','SUSPENSION','BODY','ELECTRICS','COOLING','BRAKES')),
  title           VARCHAR(200) NOT NULL,
  description     TEXT,
  severity        VARCHAR(10) NOT NULL CHECK (severity IN ('CRITICAL','MODERATE','MINOR')),
  typical_mileage INT,
  repair_cost_min DECIMAL(10,2),
  repair_cost_max DECIMAL(10,2),
  source_info     TEXT,
  created_at      TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE listing_weakness (
  id             SERIAL PRIMARY KEY,
  listing_id     INT NOT NULL REFERENCES listing(id) ON DELETE CASCADE,
  weakness_id    INT NOT NULL REFERENCES weakness(id) ON DELETE CASCADE,
  is_relevant    BOOLEAN NOT NULL,
  relevance_note TEXT,
  UNIQUE (listing_id, weakness_id)
);

CREATE TABLE favorite (
  id         SERIAL PRIMARY KEY,
  user_id    INT NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  listing_id INT NOT NULL REFERENCES listing(id) ON DELETE CASCADE,
  added_at   TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE (user_id, listing_id)
);

CREATE TABLE saved_search (
  id             SERIAL PRIMARY KEY,
  user_id        INT NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  name           VARCHAR(200) NOT NULL,
  filters_json   JSONB NOT NULL,
  notify_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  last_check     TIMESTAMP,
  created_at     TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE notification (
  id              SERIAL PRIMARY KEY,
  user_id         INT NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  saved_search_id INT REFERENCES saved_search(id) ON DELETE SET NULL,
  title           VARCHAR(200) NOT NULL,
  body            TEXT,
  is_read         BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE ai_analysis_log (
  id            SERIAL PRIMARY KEY,
  listing_id    INT REFERENCES listing(id) ON DELETE SET NULL,
  car_model_id  INT REFERENCES car_model(id) ON DELETE SET NULL,
  request_text  TEXT,
  response_text TEXT,
  status        VARCHAR(20) NOT NULL CHECK (status IN ('SUCCESS','ERROR','TIMEOUT')),
  duration_ms   INT,
  created_at    TIMESTAMP NOT NULL DEFAULT now()
);
