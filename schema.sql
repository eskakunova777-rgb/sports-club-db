-- База данных «Спортивный клуб» (SQLite)
-- Запуск: выполнить файл целиком. Повторный запуск пересоздаёт таблицы с нуля.

PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS visits;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS memberships;
DROP TABLE IF EXISTS classes;
DROP TABLE IF EXISTS trainers;
DROP TABLE IF EXISTS members;
DROP TABLE IF EXISTS membership_types;

-- Виды абонементов (тарифы клуба)
CREATE TABLE membership_types (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    name          TEXT    NOT NULL UNIQUE,
    price         INTEGER NOT NULL CHECK (price > 0),          -- рубли
    duration_days INTEGER NOT NULL CHECK (duration_days > 0)
);

-- Участники клуба
CREATE TABLE members (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    first_name  TEXT NOT NULL,
    last_name   TEXT NOT NULL,
    email       TEXT NOT NULL UNIQUE CHECK (email LIKE '%_@_%._%'),
    phone       TEXT UNIQUE,
    birth_date  TEXT NOT NULL,                                  -- YYYY-MM-DD
    joined_at   TEXT NOT NULL,                                  -- YYYY-MM-DD
    -- на момент вступления участнику должно быть не меньше 14 лет
    CHECK (birth_date <= date(joined_at, '-14 years'))
);

-- Тренеры
CREATE TABLE trainers (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    first_name     TEXT NOT NULL,
    last_name      TEXT NOT NULL,
    email          TEXT NOT NULL UNIQUE,
    specialization TEXT NOT NULL,
    hired_at       TEXT NOT NULL
);

-- Занятия в расписании: у одного тренера много занятий
CREATE TABLE classes (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    title        TEXT    NOT NULL,
    trainer_id   INTEGER NOT NULL REFERENCES trainers(id),
    room         TEXT    NOT NULL,
    starts_at    TEXT    NOT NULL,                              -- YYYY-MM-DD HH:MM
    duration_min INTEGER NOT NULL CHECK (duration_min BETWEEN 15 AND 180),
    capacity     INTEGER NOT NULL CHECK (capacity > 0)          -- мест в группе
);

-- Купленные абонементы: у участника может быть много абонементов во времени
CREATE TABLE memberships (
    id                 INTEGER PRIMARY KEY AUTOINCREMENT,
    member_id          INTEGER NOT NULL REFERENCES members(id),
    membership_type_id INTEGER NOT NULL REFERENCES membership_types(id),
    start_date         TEXT    NOT NULL,
    end_date           TEXT    NOT NULL,
    CHECK (end_date >= start_date)
);

-- Оплаты: каждая оплата относится к конкретному абонементу
CREATE TABLE payments (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    membership_id INTEGER NOT NULL REFERENCES memberships(id),
    amount        INTEGER NOT NULL CHECK (amount > 0),
    paid_at       TEXT    NOT NULL,
    method        TEXT    NOT NULL CHECK (method IN ('card', 'cash', 'transfer'))
);

-- Посещения (записи на занятия): связь «многие ко многим» между members и classes
CREATE TABLE visits (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    member_id INTEGER NOT NULL REFERENCES members(id),
    class_id  INTEGER NOT NULL REFERENCES classes(id),
    status    TEXT    NOT NULL DEFAULT 'booked'
              CHECK (status IN ('booked', 'attended', 'no_show', 'cancelled')),
    UNIQUE (member_id, class_id)                                -- нельзя записаться дважды
);

-- Индексы на внешние ключи и поля, по которым часто ищем
CREATE INDEX idx_classes_trainer_id     ON classes(trainer_id);
CREATE INDEX idx_classes_starts_at      ON classes(starts_at);
CREATE INDEX idx_memberships_member_id  ON memberships(member_id);
CREATE INDEX idx_payments_membership_id ON payments(membership_id);
CREATE INDEX idx_visits_member_id       ON visits(member_id);
CREATE INDEX idx_visits_class_id        ON visits(class_id);
