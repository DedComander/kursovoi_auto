INSERT INTO source (name, base_url) VALUES
 ('Авито','https://www.avito.ru'), ('Дром','https://auto.drom.ru'), ('Auto.ru','https://auto.ru');

INSERT INTO car_model (brand, model, generation, year_from, year_to, engines) VALUES
 ('Skoda','Octavia','A7',2013,2020,'["1.6 MPI","1.4 TSI","1.8 TSI","2.0 TDI"]'),
 ('Toyota','Camry','XV70',2017,NULL,'["2.0","2.5","3.5"]'),
 ('Volkswagen','Polo','Mk5 sedan',2010,2020,'["1.6 MPI","1.4 TSI"]');

INSERT INTO weakness (car_model_id, engine_variant, system_node, title, description, severity, typical_mileage, repair_cost_min, repair_cost_max, source_info) VALUES
 (1,'1.8 TSI','ENGINE','Повышенный расход масла','Масложор из-за тонких поршневых колец',                'CRITICAL',100000, 60000,120000,'форумы владельцев'),
 (1,NULL,'TRANSMISSION','Рывки робота DSG-7','Износ сцепления и мехатроника сухого DSG',               'MODERATE', 90000, 40000, 90000,'drive2.ru'),
 (1,NULL,'ELECTRICS','Глюки мультимедиа','Зависания головного устройства',                             'MINOR',    60000,  5000, 20000,'отзывы'),
 (2,NULL,'SUSPENSION','Стук задней подвески','Износ втулок и стоек стабилизатора',                      'MINOR',    70000,  8000, 25000,'отзывы'),
 (2,'2.5','ENGINE','Вибрации на холостых','Износ опор двигателя',                                      'MODERATE',120000, 15000, 35000,'форумы'),
 (3,'1.6 MPI','ENGINE','Гул и стук ГРМ','Износ натяжителя цепи/ремня ГРМ',                            'MODERATE', 80000, 15000, 30000,'форумы'),
 (3,NULL,'BODY','Коррозия арок и порогов','Слабое ЛКП и оцинковка',                                    'MODERATE', 70000, 20000, 60000,'отзывы'),
 (3,NULL,'COOLING','Течь помпы','Износ помпы охлаждения',                                              'MINOR',    90000,  6000, 15000,'отзывы');

INSERT INTO listing (source_id, external_id, source_url, car_model_id, brand, model, year, mileage,
  engine_volume, engine_power, fuel_type, transmission, drive_type, body_type, color, owners_count,
  condition, trim_level, price, city, description, published_date) VALUES
 (1,'av-1001','https://www.avito.ru/1001',1,'Skoda','Octavia',2016,145000,1.8,180,'Бензин','Робот','Передний','Лифтбек','Белый',2,'Не битый','Style',1050000,'Москва','Один из владельцев, сервисная история','2026-10-20'),
 (2,'dr-2002','https://auto.drom.ru/2002',1,'Skoda','Octavia',2018,62000,1.4,150,'Бензин','Механика','Передний','Лифтбек','Серый',1,'Не битый','Ambition',1290000,'Санкт-Петербург','Первый владелец','2026-10-25'),
 (3,'ar-3003','https://auto.ru/3003',2,'Toyota','Camry',2019,88000,2.5,181,'Бензин','Автомат','Передний','Седан','Чёрный',1,'Не битый','Престиж',2650000,'Москва','Официальный дилер','2026-10-27'),
 (1,'av-1004','https://www.avito.ru/1004',3,'Volkswagen','Polo',2014,168000,1.6,105,'Бензин','Автомат','Передний','Седан','Серебро',3,'Битый','Comfortline',520000,'Казань','Требует вложений','2026-10-18'),
 (2,'dr-2005','https://auto.drom.ru/2005',3,'Volkswagen','Polo',2017,95000,1.6,110,'Бензин','Механика','Передний','Седан','Синий',2,'Не битый','Trendline',780000,'Екатеринбург','Хорошее состояние','2026-10-29');

INSERT INTO listing_photo (listing_id, url, sort_order) VALUES
 (1,'https://picsum.photos/seed/oct1/800/500',0),(1,'https://picsum.photos/seed/oct1b/800/500',1),
 (2,'https://picsum.photos/seed/oct2/800/500',0),(3,'https://picsum.photos/seed/cam3/800/500',0),
 (4,'https://picsum.photos/seed/polo4/800/500',0),(5,'https://picsum.photos/seed/polo5/800/500',0);

-- тестовый пользователь создаётся через POST /auth/register
