/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Столяров Артемий dreamoftioma@yandex.ru
 * Дата: 02.11.2026
*/



-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
-- Продолжите запрос здесь
-- Используйте id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных
SELECT 
	-- город
	CASE 
		WHEN c.city_id = '6X8I' THEN 'Санкт-Петербург'
		ELSE 'ЛО'
	END AS City,
	
	--категория
	CASE 
		WHEN a.days_exposition BETWEEN 1 AND 30 THEN '1-30 days'
		WHEN a.days_exposition BETWEEN 31 AND 90 THEN '31-90 days'
		WHEN a.days_exposition BETWEEN 91 AND 180 THEN '91-180 days'
		WHEN a.days_exposition > 180 THEN '181+ days'
		ELSE 'non category'
	END AS Category,
	
	--количество продаваемых квартир
	COUNT(a.days_exposition) AS cnt_of_sold_flats,
	
	-- параметры (средняя стоимость квадратного метра, средняя площадь недвижимости, количество комнат и балконов)
	ROUND(AVG(a.last_price/f.total_area)::numeric,2) AS avg_cost_of_metre,
	ROUND(AVG(f.total_area)::numeric,2) AS avg_metres,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.rooms ASC) AS median_rooms,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.balcony ASC)::NUMERIC AS median_balconys,
	ROUND(AVG(f.ceiling_height)::numeric,2) AS avg_height,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.parks_around3000 ASC) AS median_parks_around3000
	
	FROM filtered_id AS fi
	JOIN real_estate.flats f USING(id)
	JOIN real_estate.advertisement a USING(id)
	JOIN real_estate.type t USING(type_id)
	JOIN real_estate.city c USING(city_id)
	
	WHERE (t.type = 'город') AND (a.first_day_exposition >= '2015-01-01') AND ((a.first_day_exposition + INTERVAL '1 day' * (a.days_exposition::INTEGER)) <= '2018-12-31')
	GROUP BY CASE 
		WHEN c.city_id = '6X8I' THEN 'Санкт-Петербург'
		ELSE 'ЛО'
	END,
	CASE 
		WHEN a.days_exposition BETWEEN 1 AND 30 THEN '1-30 days'
		WHEN a.days_exposition BETWEEN 31 AND 90 THEN '31-90 days'
		WHEN a.days_exposition BETWEEN 91 AND 180 THEN '91-180 days'
		WHEN a.days_exposition > 180 THEN '181+ days'
		ELSE 'non category'
	END
	ORDER BY City DESC, cnt_of_sold_flats DESC
	


-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Продолжите запрос здесь
-- Используйте id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных

    -- основной СТЕ 
base AS(
	SELECT 
		fi.id,
		a.first_day_exposition,
		a.days_exposition,
		EXTRACT(MONTH FROM a.first_day_exposition) AS month_published,	
		a.first_day_exposition + INTERVAL '1 day' * (a.days_exposition) AS last_day_exposition,
		EXTRACT(MONTH FROM (a.first_day_exposition + INTERVAL '1 day' * (a.days_exposition))) AS month_remove,
		(a.last_price/f.total_area) AS cost_of_metre,
		total_area
	FROM filtered_id AS fi
	JOIN real_estate.advertisement AS a USING(id)
	JOIN real_estate.flats AS f USING(id)
	JOIN real_estate.type AS t USING(type_id)
	WHERE (t.type = 'город') AND (a.first_day_exposition >= '2015-01-01') AND ((a.first_day_exposition + INTERVAL '1 day' * (a.days_exposition::INTEGER)) <= '2018-12-31')
),

--статистика по публикациям в месяц
stats_by_mth_pub AS(
	SELECT
		month_published,
		COUNT(id) AS cnt_of_pub,
		ROUND(AVG(cost_of_metre)::numeric,2) AS avg_cost_of_metre_pub,
		ROUND(AVG(total_area)::numeric,2) AS avg_metres_pub
	FROM base AS b
	GROUP BY month_published
),

--статистика по снятиям в месяц

stats_by_mth_rem AS(
	SELECT
		month_remove,
		COUNT(id) AS cnt_of_removed,
		ROUND(AVG(cost_of_metre)::numeric,2) AS avg_cost_of_metre_removed,
		ROUND(AVG(total_area)::numeric,2) AS avg_metres_removed
	FROM base AS b
	WHERE (month_remove IS NOT NULL) AND (days_exposition IS NOT NULL)
	GROUP BY month_remove
)

-- финальный селект
SELECT 
	--месяц
	p.month_published AS month,
	--статистика
	p.cnt_of_pub AS counter_of_publications,
	r.cnt_of_removed AS counter_of_publications_removed,
	p.avg_cost_of_metre_pub AS avg_cost_metre_publications,
	r.avg_cost_of_metre_removed AS avg_cost_metre_publications_removed,
	p.avg_metres_pub AS avg_metres_publications,
	r.avg_metres_removed AS avg_metres_publications_removed
	
FROM stats_by_mth_pub AS p
JOIN stats_by_mth_rem AS r ON p.month_published = r.month_remove

ORDER BY month