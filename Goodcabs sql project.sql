									-- ==============================================================
									--   GOODCABS OPERATIONS ANALYTICS — SQL PROJECT
									--   Analyst  : Peter Pandey  |  Reported to : Tony Sharma
									--   Domain   : Transportation & Mobility  |  Tool : MySQL
									--   Period   : Jan 2024 – Jun 2024  |  Cities : 10 Tier-2 Cities

-- ===============================================================
-- BUSINESS REQUEST - 1
-- City-Level Fare and Trip Summary Report
-- Assess trip volume, pricing efficiency, and each city's
-- contribution to overall trips.
-- ===============================================================

SELECT dc.city_name                               AS City_name,
	   COUNT(ft.trip_id)                          AS Total_trips,
	   ROUND(AVG(ft.fare_amount),2)               AS Avg_fare_per_trip,
       ROUND(AVG(ft.fare_amount) /
			 AVG(ft.distance_travelled_km),2)     AS Avg_fare_per_km,
	   ROUND(COUNT(ft.trip_id) * 100 /
			 SUM(COUNT(ft.trip_id)) OVER() ,2)    AS  pct_contribution_to_total_trips
	   
FROM dim_city dc 
JOIN fact_trips ft ON dc.city_id = ft.city_id
GROUP BY dc.city_name
ORDER BY Avg_fare_per_trip DESC;


-- ============================================================
-- BUSINESS REQUEST - 2
-- Monthly City-Level Trips Target Performance Report
-- Compare actual trips vs target trips at city × month level.
-- Flag each row as "Above Target" or "Below Target" and
-- calculate the % performance gap.
-- ============================================================

WITH Actual_monthly_trips AS (
				SELECT dc.city_id                            AS City_id,
					   dd.start_of_month                     AS start_of_month,
					   dd.month_name                           AS Month_name,
					   COUNT(ft.trip_id)                       AS Actual_trips
				FROM dim_city dc
				JOIN fact_trips ft ON dc.city_id = ft.city_id
				JOIN dim_date dd ON dd.date_id = ft.date_id
				GROUP BY dc.city_id ,dd.start_of_month, dd.month_name
)
SELECT dc.City_name,
	   amt.Month_name,
       amt.Actual_trips,
       mtt.total_target_trips                                                    AS Target_trips,
       CASE
			WHEN  amt.Actual_trips > mtt.total_target_trips THEN 'Above Target'
            ELSE 'Below'
	   END                               										 AS Performance_status,
       ROUND(
			 (amt.Actual_trips - mtt.total_target_trips) * 100 /
               NULLIF(mtt.total_target_trips,0) , 2 )                            AS pct_gap

FROM actual_monthly_trips amt 
JOIN monthly_target_trips mtt ON amt.city_id = mtt.city_id
							AND amt.start_of_month = mtt.start_of_month
JOIN dim_city dc  ON dc.city_id = amt.city_id
ORDER BY dc.city_name , amt.start_of_month
;

-- ============================================================
-- BUSINESS REQUEST - 3
-- City-Level Repeat Passenger Trip Frequency Report
--  Show what % of repeat passengers in each city took
--  2, 3, 4 … 10 trips. Pivot trip_count rows into columns.
-- ============================================================

WITH repeat_passengers AS ( 
				  SELECT dc.City_name                            AS City_name,
                         drt.trip_count                          AS Trip_count,
                         SUM(drt.repeat_passenger_count)         AS Total_repeat_passenger
				  FROM dim_city dc
                  JOIN dim_repeat_trip_distribution drt ON drt.city_id = dc.city_id 
                  GROUP BY dc.city_name, drt.trip_count 
), 
 Total_passenger AS(
			SELECT city_name,
				   trip_count,
                   total_repeat_passenger,
                   SUM(total_repeat_passenger) OVER(PARTITION BY city_name) AS Total_passenger
			FROM repeat_passengers
)
SELECT City_name,
	   ROUND(SUM(CASE WHEN trip_count = '2-trips' THEN total_repeat_passenger * 100 / Total_passenger END),2)  AS '2-Trips',
	   ROUND(SUM(CASE WHEN trip_count = '3-trips' THEN total_repeat_passenger * 100 / Total_passenger END),2)  AS '3-Trips',
	   ROUND(SUM(CASE WHEN trip_count = '4-trips' THEN total_repeat_passenger * 100 / Total_passenger END),2)  AS '4-Trips',
	   ROUND(SUM(CASE WHEN trip_count = '5-trips' THEN total_repeat_passenger * 100 / Total_passenger END),2)  AS '5-Trips',
	   ROUND(SUM(CASE WHEN trip_count = '6-trips' THEN total_repeat_passenger * 100 / Total_passenger END),2)  AS '6-Trips',
	   ROUND(SUM(CASE WHEN trip_count = '7-trips' THEN total_repeat_passenger * 100 / Total_passenger END),2)  AS '7-Trips',
	   ROUND(SUM(CASE WHEN trip_count = '8-trips' THEN total_repeat_passenger * 100 / Total_passenger END),2)  AS '8-Trips',
	   ROUND(SUM(CASE WHEN trip_count = '9-trips' THEN total_repeat_passenger * 100 / Total_passenger END),2)  AS '9-Trips',
	   ROUND(SUM(CASE WHEN trip_count = '10-trips' THEN total_repeat_passenger * 100 / Total_passenger END),2)  AS '10-Trips'
FROM Total_passenger
GROUP BY City_name
ORDER BY City_name
;


-- ============================================================
-- BUSINESS REQUEST - 4
-- Identify Cities with Highest and Lowest Total New Passengers
-- Rank all cities by new passenger volume.
-- Label Top 3 and Bottom 3 cities.
-- ============================================================

WITH City_trips_total AS ( 
				SELECT dc.city_name                       AS City_name,
					   SUM(fps.new_passengers)            AS New_passengers
				FROM dim_city dc 
                JOIN fact_passenger_summary fps ON dc.city_id = fps.city_id
                GROUP BY dc.city_name
),
ranked_city AS (
			SELECT City_name,
				   New_passengers,
				   RANK() OVER(ORDER BY New_passengers DESC) as Rank_desc,
                   RANK() OVER(ORDER BY New_passengers ASC) as Rank_asc
			FROM city_trips_total
)
SELECT City_name,
	   New_passengers,
       CASE 
			WHEN Rank_desc <= 3 THEN 'Top 3'
			WHEN Rank_asc <= 3 THEN 'Bottom 3'
            END AS Performance_category
FROM ranked_city
WHERE rank_desc <= 3 or rank_asc <= 3
ORDER BY New_passengers desc
;


-- ============================================================
-- BUSINESS REQUEST - 5
-- Identify Month with Highest Revenue for Each City
-- For each city, find the single month that generated
-- the most revenue and calculate its % share of that
-- city's full-period revenue.
-- ============================================================

WITH monthly_Revenue AS(
				SELECT dc.city_name                               AS City_name,
					   dd.month_name                              AS Month_name,
					   SUM(ft.fare_amount)                        AS Total_revenue
				FROM dim_city dc 
				JOIN fact_trips ft ON dc.city_id = ft.city_id
				JOIN dim_date dd ON dd.date_id = ft.date_id
				GROUP BY dc.city_name, dd.month_name
),
Ranked AS (
		SELECT city_name,
			   month_name,
               Total_revenue,
               SUM(total_revenue)  OVER(PARTITION BY city_name)                                             AS overall_revenue ,
               RANK() OVER(PARTITION BY city_name ORDER BY Total_revenue DESC) as rank_Highest
		FROM monthly_revenue
        
)
SELECT city_name,                                                             
       MAX(CASE WHEN rank_Highest = 1 THEN month_name END)   AS peak_demand_month,                 -- [MAX() here is used to convert multiple rows 
       MAX(CASE WHEN rank_Highest = 1 THEN Total_revenue END)  AS Highest_revenue,                 -- into a single row per city after GROUP BY city_name
       MAX(ROUND((Total_revenue * 100 / overall_revenue),2))      AS city_total_rev_share_pct      -- into a single row per city after GROUP BY city_name]
       
FROM Ranked 
WHERE rank_Highest = 1                                                  
GROUP BY city_name
ORDER BY City_name;


-- ============================================================
-- BUSINESS REQUEST - 6
-- Repeat Passenger Rate Analysis
-- Calculate two RPR metrics:
--   1. monthly_repeat_passenger_rate : RPR% at city × month level
--   2. city_repeat_passenger_rate    : Overall RPR% per city
--                                      across the full period
-- ============================================================


WITH Overall_city_rpr AS (
				SELECT city_id,
					   ROUND(SUM(repeat_passengers) * 100 /
                       NULLIF(SUM(total_passengers),0) ,2 )          AS city_Rpr_pct
				FROM fact_passenger_summary
                GROUP BY city_id
)
SELECT dc.city_name,
	   DATE_FORMAT(fps.start_of_month,'%M %Y')            AS Month_Year,
	   fps.total_passengers,
	   fps.repeat_passengers,
-- rpr% at city-month level
	   ROUND(fps.repeat_passengers * 100 /
			 NULLIF(fps.total_passengers,0),2)            AS Monthly_rpr,
					
-- Overall RPR% for the city across all 6 months
      
		ocr.city_Rpr_pct
FROM dim_city dc 
JOIN fact_passenger_summary fps ON fps.city_id = dc.city_id
JOIN overall_city_rpr ocr ON fps.city_id = ocr.city_id
ORDER BY dc.city_name,fps.start_of_month
;
            
-- =============================================================
-- END OF AD-HOC REQUESTS
-- =============================================================