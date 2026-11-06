/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * Автор: Столяров Артемий tema.stolyarov@bk.ru
*/

-- Часть 1. Исследовательский анализ данных
-- Исследование доли платящих игроков

-- Доля платящих пользователей по всем данным:

SELECT 
    COUNT(*) AS total_users,
    SUM(payer) AS payment_users,
    ROUND(AVG(payer)::numeric, 4) AS payment_part_of_users
FROM fantasy.users;

-- Доля платящих пользователей в разрезе расы персонажа:

SELECT 
    r.race,
    COUNT(u.id) AS total_users_race,
    SUM(u.payer) AS payment_users_by_race,
    ROUND(AVG(u.payer)::numeric, 4) AS payment_part_of_users_race
FROM fantasy.users u
LEFT JOIN fantasy.race r USING(race_id)
GROUP BY r.race_id, r.race
ORDER BY payment_users_by_race DESC;
-- Исследование внутриигровых покупок
-- Статистические показатели по полю amount:

SELECT 
    COUNT(transaction_id) AS total_transactions,
    SUM(amount) AS total_amount,
    MIN(amount) AS min_amount,
    MAX(amount) AS max_amount,
    ROUND(AVG(amount)::numeric, 2) AS avg_amount,
    PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY amount) AS median_amount,
    ROUND(STDDEV(amount)::numeric, 2) AS stddev_amount
FROM fantasy.events;

-- Статистика без нулевых покупок:

SELECT 
    COUNT(transaction_id) AS total_transactions,
    ROUND(AVG(amount)::numeric, 2) AS avg_amount,
    PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY amount) AS median_amount,
    MIN(amount) AS min_amount
FROM fantasy.events
WHERE amount > 0;

-- Аномальные нулевые покупки:

SELECT 
    COUNT(transaction_id) AS total_transactions,
    COUNT(transaction_id) FILTER (WHERE amount = 0) AS zero_amount_transactions,
    ROUND(
        (COUNT(transaction_id) FILTER (WHERE amount = 0)::float / 
         COUNT(transaction_id))::numeric, 
        4
    ) AS part_zero_transactions
FROM fantasy.events;

-- Популярные эпические предметы (включая непокупавшиеся):

WITH item_stats AS (
    SELECT 
        item_code,
        COUNT(*) AS total_sales,
        COUNT(DISTINCT id) AS unique_buyers
    FROM fantasy.events
    WHERE amount > 0
    GROUP BY item_code
)

SELECT 
    i.game_items,
    s.item_code,
    COALESCE(s.total_sales, 0) AS total_sales,
    COALESCE(s.unique_buyers, 0) AS unique_buyers,
    ROUND(
        (s.total_sales::float / NULLIF(SUM(s.total_sales) OVER(), 0))::numeric, 
        4
    ) AS part_of_total_sales,
    ROUND(
        (s.unique_buyers::float / NULLIF((SELECT COUNT(DISTINCT id) FROM fantasy.events WHERE amount > 0), 0))::numeric, 
        4
    ) AS part_of_buyers
FROM fantasy.items i
LEFT JOIN item_stats s USING(item_code)
ORDER BY total_sales DESC;


-- Часть 2. Решение ad hoc-задачи
-- Зависимость активности игроков от расы персонажа:

WITH total_users AS (
    SELECT 
        race_id,
        COUNT(*) AS total_users
    FROM fantasy.users
    GROUP BY race_id
),
buyers AS (
    SELECT 
        u.race_id,
        COUNT(DISTINCT u.id) AS buyers_count,
        COUNT(DISTINCT CASE WHEN u.payer = 1 THEN u.id END) AS payer_buyers_count
    FROM fantasy.users u
    JOIN fantasy.events e ON u.id = e.id AND e.amount > 0
    GROUP BY u.race_id
),
activity AS (
    SELECT 
        u.race_id,
        COUNT(e.transaction_id) AS total_transactions,
        SUM(e.amount) AS total_amount
    FROM fantasy.users u
    JOIN fantasy.events e ON u.id = e.id AND e.amount > 0
    GROUP BY u.race_id
)

SELECT 
	r.race,
    t.race_id,
    t.total_users,
    b.buyers_count,
    CASE WHEN t.total_users = 0 THEN NULL 
         ELSE ROUND((b.buyers_count::float / t.total_users)::numeric, 4) END AS buyers_share,
    CASE WHEN b.buyers_count = 0 THEN NULL 
         ELSE ROUND((b.payer_buyers_count::float / b.buyers_count)::numeric, 4) END AS payer_share,
    CASE WHEN b.buyers_count = 0 THEN NULL 
         ELSE ROUND((a.total_transactions::float / b.buyers_count)::numeric, 4) END AS avg_trans_per_buyer,
    CASE WHEN a.total_transactions = 0 THEN NULL 
         ELSE ROUND((a.total_amount::float / a.total_transactions)::numeric, 4) END AS avg_amount_per_trans,
    CASE WHEN b.buyers_count = 0 THEN NULL 
         ELSE ROUND((a.total_amount::float / b.buyers_count)::numeric, 2) END AS avg_total_amount_per_buyer
FROM total_users t
LEFT JOIN buyers b USING(race_id)
LEFT JOIN activity a USING(race_id)
LEFT JOIN fantasy.race r USING(race_id)
ORDER BY r.race;



