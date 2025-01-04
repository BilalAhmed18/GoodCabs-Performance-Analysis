-- BUSINESS REQUEST - 1: City-Level Fare and Trips Summary Report

SELECT  
    c.city_name,  
    COUNT(f.trip_id) AS total_trips,  
    ROUND(SUM(f.fare_amount) / SUM(f.distance_travelled_km), 2) AS avg_fare_per_km,  
    CONCAT(
	 ROUND((COUNT(f.trip_id) * 100.0) / SUM(COUNT(f.trip_id)) OVER (), 2), '%') AS pct_contribution_to_total_trips  
FROM fact_trips f  
JOIN dim_city c ON c.city_id = f.city_id  
GROUP BY c.city_name;



-- BUSINESS REQUEST - 2: Monthly City-Level Trips Target Performance Report

SELECT 
    c.city_name,
    d.month_name,
    COUNT(f.trip_id) AS actual_trips,
    MAX(t.total_target_trips) AS target_trips,
    CASE
        WHEN COUNT(f.trip_id) > MAX(t.total_target_trips) THEN 'Above Target'
        ELSE 'Below Target'
    END AS target_status,
    CASE
        WHEN MAX(t.total_target_trips) > 0 THEN
            CONCAT(ROUND(((COUNT(f.trip_id) - MAX(t.total_target_trips)) / MAX(t.total_target_trips)) * 100, 2),'%')
        ELSE 0
    END AS percentage_difference
FROM fact_trips f
LEFT JOIN dim_city c ON c.city_id = f.city_id
LEFT JOIN dim_date d ON d.date = f.date
LEFT JOIN targets_db.monthly_target_trips t ON t.city_id = f.city_id AND t.month = f.date
GROUP BY c.city_name, d.month_name;



-- BUSINESS REQUEST - 3: City-Level Repeat Passenger Trip Frequency Report

WITH CTE1 AS (
    SELECT 
    city_id, trip_count, SUM(repeat_passenger_count) AS Total_RP
    FROM dim_repeat_trip_distribution
    GROUP BY city_id, trip_count
),
CTE2 AS (
    SELECT 
        city_id, 
        trip_count, 
        SUM(Total_RP) OVER (PARTITION BY city_id) AS city_total_RP,
        CONCAT(ROUND((Total_RP * 100.0) / SUM(Total_RP) OVER (PARTITION BY city_id), 2), '%') AS contribution_pct
    FROM CTE1
)
SELECT 
    city_name,
	MAX(CASE WHEN trip_count = '2-trips' THEN contribution_pct ELSE 0 END) AS '2-trips',
    MAX(CASE WHEN trip_count = '3-trips' THEN contribution_pct ELSE 0 END) AS '3-trips',
    MAX(CASE WHEN trip_count = '4-trips' THEN contribution_pct ELSE 0 END) AS '4-trips',
    MAX(CASE WHEN trip_count = '5-trips' THEN contribution_pct ELSE 0 END) AS '5-trips',
    MAX(CASE WHEN trip_count = '6-trips' THEN contribution_pct ELSE 0 END) AS '6-trips',
    MAX(CASE WHEN trip_count = '7-trips' THEN contribution_pct ELSE 0 END) AS '7-trips',
    MAX(CASE WHEN trip_count = '8-trips' THEN contribution_pct ELSE 0 END) AS '8-trips',
    MAX(CASE WHEN trip_count = '9-trips' THEN contribution_pct ELSE 0 END) AS '9-trips',
    MAX(CASE WHEN trip_count = '10-trips' THEN contribution_pct ELSE 0 END) AS '10-trips'
FROM CTE2
JOIN dim_city ON CTE2.city_id = dim_city.city_id
GROUP BY city_name;


-- BUSINESS REQUEST - 4: Identify Cities with Highest and Lowest New Passengers 

(
    SELECT 
        city_name,
        SUM(new_passengers) AS total_new_passengers,
        'Top 3' AS category
    FROM fact_passenger_summary p
    LEFT JOIN dim_city c ON c.city_id = p.city_id
    GROUP BY city_name
    ORDER BY total_new_passengers DESC
    LIMIT 3
)
UNION ALL
(
    SELECT 
        city_name,
        SUM(new_passengers) AS total_new_passengers,
        'Bottom 3' AS category
    FROM fact_passenger_summary p
    LEFT JOIN dim_city c ON c.city_id = p.city_id
    GROUP BY city_name
    ORDER BY total_new_passengers ASC
    LIMIT 3
);



-- BUSINESS REQUEST - 5: Identify Month with Highest Revenue for Each City

WITH CityMonthlyRevenue AS (
    SELECT 
        c.city_name,
        d.month_name,
        SUM(t.fare_amount) AS revenue
    FROM fact_trips t
    LEFT JOIN dim_city c ON c.city_id = t.city_id
    LEFT JOIN dim_date d ON d.date = t.date
    GROUP BY c.city_name, d.month_name
),
CityTotalRevenue AS (
    SELECT 
        city_name,
        SUM(revenue) AS total_revenue
    FROM CityMonthlyRevenue
    GROUP BY city_name
)
SELECT 
    cmr.city_name,
    cmr.month_name AS highest_revenue_month,
    cmr.revenue,
    CONCAT(ROUND((cmr.revenue / ctr.total_revenue) * 100,2),'%') AS pct_contribution
FROM (
    SELECT 
        city_name,
        month_name,
        revenue,
        RANK() OVER (PARTITION BY city_name ORDER BY revenue DESC) AS revenue_rank
    FROM CityMonthlyRevenue
) cmr
JOIN CityTotalRevenue ctr ON cmr.city_name = ctr.city_name
WHERE cmr.revenue_rank = 1;



-- Business Request - 6: Monthly Repeat Passenger Rate Analysis

SELECT 
    c.city_name,
    d.month_name,
    SUM(p.total_passengers) AS total_passenger,
    SUM(p.repeat_passengers) AS repeat_passengers,
    CONCAT(ROUND(SUM(p.repeat_passengers) / SUM(p.total_passengers) * 100, 2), '%') AS monthly_RPR_pct
FROM fact_passenger_summary p
LEFT JOIN dim_city c ON c.city_id = p.city_id
LEFT JOIN dim_date d ON d.date = p.month
GROUP BY c.city_name, d.month_name
ORDER BY c.city_name, d.month_name;


-- Business Request - 6: City Repeat Passenger Rate Analysis

SELECT 
    c.city_name,
    SUM(p.total_passengers) AS city_total_passengers,
    SUM(p.repeat_passengers) AS city_repeat_passengers,
    CONCAT(ROUND(SUM(p.repeat_passengers) / SUM(p.total_passengers) * 100, 2), '%') AS city_RPR_pct
FROM fact_passenger_summary p
LEFT JOIN dim_city c ON c.city_id = p.city_id
GROUP BY c.city_name;


