-- Toy store chain: sales and inventory analysis
-- Tables: sales, products, stores, inventory (loaded from the CSV files in data/)
-- Written and tested in SQLite. Uses standard SQL (JOINs, CTEs, subqueries,
-- window functions) that also runs in MySQL 8 and PostgreSQL; only SUBSTR is used for dates.

-- 1. Overall KPIs
SELECT COUNT(*)                                              AS sale_lines,
       SUM(s.Units)                                          AS units_sold,
       ROUND(SUM(s.Units * p.Product_Price))                 AS revenue,
       ROUND(SUM(s.Units * (p.Product_Price - p.Product_Cost))) AS profit,
       ROUND(100.0 * SUM(s.Units * (p.Product_Price - p.Product_Cost))
             / SUM(s.Units * p.Product_Price), 1)            AS margin_pct
FROM sales s
JOIN products p ON s.Product_ID = p.Product_ID;

-- 2. Same month, 2022 vs 2023 (self-join on a CTE)
WITH monthly AS (
    SELECT SUBSTR(s.Month, 1, 4)              AS yr,
           SUBSTR(s.Month, 6, 2)              AS mon,
           SUM(s.Units * p.Product_Price)     AS revenue
    FROM sales s
    JOIN products p ON s.Product_ID = p.Product_ID
    GROUP BY s.Month
)
SELECT a.mon                                             AS month,
       ROUND(a.revenue)                                  AS revenue_2022,
       ROUND(b.revenue)                                  AS revenue_2023,
       ROUND(100.0 * (b.revenue - a.revenue) / a.revenue, 1) AS growth_pct
FROM monthly a
JOIN monthly b ON a.mon = b.mon AND a.yr = '2022' AND b.yr = '2023'
ORDER BY a.mon;

-- 3. Month-on-month change (LAG)
WITH monthly AS (
    SELECT s.Month,
           SUM(s.Units * p.Product_Price) AS revenue
    FROM sales s
    JOIN products p ON s.Product_ID = p.Product_ID
    GROUP BY s.Month
)
SELECT Month,
       ROUND(revenue) AS revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY Month))
             / LAG(revenue) OVER (ORDER BY Month), 1) AS mom_change_pct
FROM monthly
ORDER BY Month;

-- 4. Revenue vs profit by category (share of total with a subquery)
WITH category_totals AS (
    SELECT p.Product_Category                                    AS category,
           SUM(s.Units * p.Product_Price)                        AS revenue,
           SUM(s.Units * (p.Product_Price - p.Product_Cost))     AS profit
    FROM sales s
    JOIN products p ON s.Product_ID = p.Product_ID
    GROUP BY p.Product_Category
)
SELECT category,
       ROUND(revenue) AS revenue,
       ROUND(profit)  AS profit,
       ROUND(100.0 * revenue / (SELECT SUM(revenue) FROM category_totals), 1) AS revenue_share_pct,
       ROUND(100.0 * profit  / (SELECT SUM(profit)  FROM category_totals), 1) AS profit_share_pct,
       ROUND(100.0 * profit / revenue, 1)                                     AS margin_pct
FROM category_totals
ORDER BY profit DESC;

-- 5. Top 3 products in each category (ROW_NUMBER)
WITH product_profit AS (
    SELECT p.Product_Category AS category,
           p.Product_Name     AS product,
           ROUND(SUM(s.Units * (p.Product_Price - p.Product_Cost))) AS profit
    FROM sales s
    JOIN products p ON s.Product_ID = p.Product_ID
    GROUP BY p.Product_Category, p.Product_Name
),
ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY category ORDER BY profit DESC) AS rank_in_category,
           ROUND(100.0 * profit / (SELECT SUM(profit) FROM product_profit), 1) AS share_of_total_profit_pct
    FROM product_profit
)
SELECT category, rank_in_category, product, profit, share_of_total_profit_pct
FROM ranked
WHERE rank_in_category <= 3
ORDER BY category, rank_in_category;

-- 6. Profit per store by store location (3-table JOIN)
SELECT st.Store_Location                                      AS location,
       COUNT(DISTINCT st.Store_ID)                            AS stores,
       ROUND(SUM(s.Units * (p.Product_Price - p.Product_Cost))) AS profit,
       ROUND(SUM(s.Units * (p.Product_Price - p.Product_Cost))
             / COUNT(DISTINCT st.Store_ID))                   AS profit_per_store
FROM sales s
JOIN products p ON s.Product_ID = p.Product_ID
JOIN stores  st ON s.Store_ID   = st.Store_ID
GROUP BY st.Store_Location
ORDER BY profit_per_store DESC;

-- 7. Store ranking overall and within location (RANK)
WITH store_profit AS (
    SELECT st.Store_Name, st.Store_Location,
           ROUND(SUM(s.Units * (p.Product_Price - p.Product_Cost))) AS profit
    FROM sales s
    JOIN products p ON s.Product_ID = p.Product_ID
    JOIN stores  st ON s.Store_ID   = st.Store_ID
    GROUP BY st.Store_ID, st.Store_Name, st.Store_Location
)
SELECT Store_Name, Store_Location, profit,
       RANK() OVER (ORDER BY profit DESC)                          AS overall_rank,
       RANK() OVER (PARTITION BY Store_Location ORDER BY profit DESC) AS rank_in_location
FROM store_profit
ORDER BY profit DESC;

-- 8. Stores below the average store profit (subquery)
WITH store_profit AS (
    SELECT s.Store_ID,
           SUM(s.Units * (p.Product_Price - p.Product_Cost)) AS profit
    FROM sales s
    JOIN products p ON s.Product_ID = p.Product_ID
    GROUP BY s.Store_ID
)
SELECT st.Store_Name, st.Store_Location, ROUND(sp.profit) AS profit
FROM store_profit sp
JOIN stores st ON sp.Store_ID = st.Store_ID
WHERE sp.profit < (SELECT AVG(profit) FROM store_profit)
ORDER BY sp.profit;

-- 9. Money tied up in stock
SELECT ROUND(SUM(i.Stock_On_Hand * p.Product_Cost))          AS stock_value_at_cost,
       SUM(i.Stock_On_Hand)                                  AS units_in_stock,
       COUNT(*)                                              AS store_product_lines,
       SUM(CASE WHEN i.Stock_On_Hand = 0 THEN 1 ELSE 0 END)  AS out_of_stock_lines
FROM inventory i
JOIN products p ON i.Product_ID = p.Product_ID;

-- 10. Days of stock cover per store and product (LEFT JOIN + CASE)
-- average daily sales over the last 3 months of data (1 Jul to 30 Sep 2023 = 92 days)
WITH recent AS (
    SELECT Store_ID, Product_ID, SUM(Units) / 92.0 AS avg_daily_units
    FROM sales
    WHERE Date >= '2023-07-01'
    GROUP BY Store_ID, Product_ID
),
cover AS (
    SELECT i.Store_ID, i.Product_ID, i.Stock_On_Hand, r.avg_daily_units,
           i.Stock_On_Hand / r.avg_daily_units AS days_of_cover
    FROM inventory i
    LEFT JOIN recent r ON i.Store_ID = r.Store_ID AND i.Product_ID = r.Product_ID
)
SELECT CASE WHEN avg_daily_units IS NULL THEN '5. No sales in last 3 months'
            WHEN Stock_On_Hand = 0      THEN '1. Out of stock'
            WHEN days_of_cover < 7      THEN '2. Less than 1 week'
            WHEN days_of_cover < 30     THEN '3. 1 to 4 weeks'
            ELSE                             '4. More than 30 days'
       END                         AS stock_status,
       COUNT(*)                    AS store_product_lines
FROM cover
GROUP BY stock_status
ORDER BY stock_status;

-- 11. Sales lost every day to stock-outs
WITH recent AS (
    SELECT Store_ID, Product_ID, SUM(Units) / 92.0 AS avg_daily_units
    FROM sales
    WHERE Date >= '2023-07-01'
    GROUP BY Store_ID, Product_ID
)
SELECT p.Product_Name,
       COUNT(*)                                          AS stores_out_of_stock,
       ROUND(SUM(r.avg_daily_units * p.Product_Price))   AS daily_revenue_lost
FROM inventory i
JOIN recent   r ON i.Store_ID = r.Store_ID AND i.Product_ID = r.Product_ID
JOIN products p ON i.Product_ID = p.Product_ID
WHERE i.Stock_On_Hand = 0
GROUP BY p.Product_Name
ORDER BY daily_revenue_lost DESC;

