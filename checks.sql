-- Проверочные запросы. Выполнять после schema.sql и seed.sql.
-- Отчётная дата зафиксирована как '2026-11-07', чтобы результаты совпадали с README.
-- Для «живой» даты замените '2026-11-07' на date('now').

-- 1. Кто сейчас имеет активный абонемент
WITH params AS (SELECT '2026-11-07' AS today)
SELECT m.first_name || ' ' || m.last_name           AS member,
       mt.name                                      AS membership,
       ms.start_date,
       ms.end_date,
       CAST(julianday(ms.end_date) - julianday(p.today) AS INTEGER) AS days_left
FROM memberships ms
JOIN members m           ON m.id  = ms.member_id
JOIN membership_types mt ON mt.id = ms.membership_type_id
CROSS JOIN params p
WHERE p.today BETWEEN ms.start_date AND ms.end_date
ORDER BY days_left;

-- 2. Сколько людей записано на занятия по датам
SELECT date(c.starts_at)          AS class_date,
       COUNT(DISTINCT c.id)       AS classes,
       COUNT(v.id)                AS bookings,
       COUNT(DISTINCT v.member_id) AS people
FROM classes c
LEFT JOIN visits v ON v.class_id = c.id AND v.status <> 'cancelled'
GROUP BY date(c.starts_at)
ORDER BY class_date;

-- 3. Список тренеров и их занятия
SELECT t.first_name || ' ' || t.last_name AS trainer,
       t.specialization,
       c.title,
       c.starts_at,
       c.room
FROM trainers t
LEFT JOIN classes c ON c.trainer_id = t.id
ORDER BY trainer, c.starts_at;

-- 4. Участники, которые давно (больше 21 дня) не посещали клуб или не были ни разу
WITH params AS (SELECT '2026-11-07' AS today),
last_visit AS (
    SELECT v.member_id, MAX(date(c.starts_at)) AS last_date
    FROM visits v
    JOIN classes c ON c.id = v.class_id
    WHERE v.status = 'attended'
    GROUP BY v.member_id
)
SELECT m.first_name || ' ' || m.last_name AS member,
       m.email,
       COALESCE(lv.last_date, 'ни разу')  AS last_visit,
       CAST(julianday(p.today) - julianday(lv.last_date) AS INTEGER) AS days_ago
FROM members m
LEFT JOIN last_visit lv ON lv.member_id = m.id
CROSS JOIN params p
WHERE lv.last_date IS NULL
   OR julianday(p.today) - julianday(lv.last_date) > 21
ORDER BY lv.last_date;

-- 5. Топ-3 самых популярных занятий (по числу записей без отмен)
SELECT c.title,
       COUNT(DISTINCT c.id) AS sessions,
       COUNT(v.id)          AS bookings
FROM classes c
JOIN visits v ON v.class_id = c.id AND v.status <> 'cancelled'
GROUP BY c.title
ORDER BY bookings DESC
LIMIT 3;

-- 6. Сколько клуб заработал по видам абонементов
SELECT mt.name                    AS membership,
       COUNT(pay.id)              AS payments,
       COALESCE(SUM(pay.amount), 0) AS revenue_rub
FROM membership_types mt
LEFT JOIN memberships ms ON ms.membership_type_id = mt.id
LEFT JOIN payments pay   ON pay.membership_id = ms.id
GROUP BY mt.id
ORDER BY revenue_rub DESC;

-- 7. Конфликты в расписании: у участника пересекаются занятия по времени
SELECT m.first_name || ' ' || m.last_name AS member,
       c1.title || ' ' || c1.starts_at   AS class_1,
       c2.title || ' ' || c2.starts_at   AS class_2
FROM visits v1
JOIN visits v2  ON v2.member_id = v1.member_id AND v2.class_id > v1.class_id
JOIN classes c1 ON c1.id = v1.class_id
JOIN classes c2 ON c2.id = v2.class_id
JOIN members m  ON m.id  = v1.member_id
WHERE v1.status <> 'cancelled'
  AND v2.status <> 'cancelled'
  AND datetime(c1.starts_at) < datetime(c2.starts_at, '+' || c2.duration_min || ' minutes')
  AND datetime(c2.starts_at) < datetime(c1.starts_at, '+' || c1.duration_min || ' minutes');

-- 8. Заполняемость каждого занятия (дополнительный)
SELECT c.title,
       c.starts_at,
       c.capacity,
       COUNT(v.id) AS booked,
       ROUND(100.0 * COUNT(v.id) / c.capacity, 1) AS fill_pct
FROM classes c
LEFT JOIN visits v ON v.class_id = c.id AND v.status <> 'cancelled'
GROUP BY c.id
ORDER BY fill_pct DESC;

-- 9. Абонементы, которые закончатся в ближайшие 7 дней: кому напомнить о продлении (дополнительный)
WITH params AS (SELECT '2026-11-07' AS today)
SELECT m.first_name || ' ' || m.last_name AS member,
       m.phone,
       mt.name AS membership,
       ms.end_date
FROM memberships ms
JOIN members m           ON m.id  = ms.member_id
JOIN membership_types mt ON mt.id = ms.membership_type_id
CROSS JOIN params p
WHERE ms.end_date BETWEEN p.today AND date(p.today, '+7 days')
ORDER BY ms.end_date;

-- 10. Нагрузка тренеров: занятия, пришедшие и неявки (дополнительный)
SELECT t.first_name || ' ' || t.last_name AS trainer,
       COUNT(DISTINCT c.id)                                    AS classes,
       SUM(CASE WHEN v.status = 'attended' THEN 1 ELSE 0 END) AS attended,
       SUM(CASE WHEN v.status = 'no_show'  THEN 1 ELSE 0 END) AS no_shows
FROM trainers t
LEFT JOIN classes c ON c.trainer_id = t.id
LEFT JOIN visits v  ON v.class_id = c.id
GROUP BY t.id
ORDER BY attended DESC;
