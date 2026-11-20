/*
================================================================
PROJECT : SQL EXPLORATORY DATA ANALYSIS (EDA)
DATABASE: MySQL 8.0+ (window functions and CTEs need 8.0)
SCHEMA  : gold  (fact_sales, dim_customers, dim_products)

CONTENTS
  00 Optional setup (create tables + load CSVs)
  01 Database Exploration     02 Dimensions Exploration
  03 Date Exploration         04 Measures Exploration / KPIs
  05 Magnitude Analysis       06 Ranking Analysis
  07 Ranking Exploration (window functions)

Result comments were verified against the three CSV files
(60,398 sales rows / 18,484 customers / 295 products).
================================================================
*/


/*
================================================================
00. OPTIONAL SETUP - run only if the tables do not exist yet
    (Skip if you already imported with MySQL Workbench's
     Table Data Import Wizard.)
    LOAD DATA LOCAL needs:  SET GLOBAL local_infile = 1;
    Empty CSV cells are converted to NULL with NULLIF().
================================================================
*/

CREATE DATABASE IF NOT EXISTS gold;
USE gold;

CREATE TABLE IF NOT EXISTS dim_customers (
    customer_key    INT PRIMARY KEY,
    customer_id     INT,
    customer_number VARCHAR(20),
    first_name      VARCHAR(50),
    last_name       VARCHAR(50),
    country         VARCHAR(50),
    marital_status  VARCHAR(20),
    gender          VARCHAR(20),
    birthdate       DATE,
    create_date     DATE
);

CREATE TABLE IF NOT EXISTS dim_products (
    product_key    INT PRIMARY KEY,
    product_id     INT,
    product_number VARCHAR(50),
    product_name   VARCHAR(100),
    category_id    VARCHAR(20),
    category       VARCHAR(50),
    subcategory    VARCHAR(50),
    maintenance    VARCHAR(10),
    cost           INT,
    product_line   VARCHAR(30),
    start_date     DATE
);

CREATE TABLE IF NOT EXISTS fact_sales (
    order_number  VARCHAR(20),
    product_key   INT,
    customer_key  INT,
    order_date    DATE,
    shipping_date DATE,
    due_date      DATE,
    sales_amount  INT,
    quantity      INT,
    price         INT
);

/* -- Uncomment and edit the paths to load the data --

LOAD DATA LOCAL INFILE 'C:/path/gold_dim_customers.csv'
INTO TABLE dim_customers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES
(customer_key, customer_id, customer_number, first_name, last_name,
 @country, marital_status, @gender, @birthdate, create_date)
SET country   = NULLIF(@country, ''),
    gender    = NULLIF(@gender, ''),
    birthdate = NULLIF(@birthdate, '');

LOAD DATA LOCAL INFILE 'C:/path/gold_dim_products.csv'
INTO TABLE dim_products
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES
(product_key, product_id, product_number, product_name, @category_id,
 @category, @subcategory, @maintenance, cost, @product_line, start_date)
SET category_id  = NULLIF(@category_id, ''),
    category     = NULLIF(@category, ''),
    subcategory  = NULLIF(@subcategory, ''),
    maintenance  = NULLIF(@maintenance, ''),
    product_line = NULLIF(@product_line, '');

LOAD DATA LOCAL INFILE 'C:/path/gold_fact_sales.csv'
INTO TABLE fact_sales
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES
(order_number, product_key, customer_key, @order_date, shipping_date,
 due_date, sales_amount, quantity, price)
SET order_date = NULLIF(@order_date, '');

*/

USE gold;


/*==============================================================
01. DATABASE EXPLORATION
==============================================================*/

-- Q1. What tables and views exist in the current database?
SELECT
    TABLE_SCHEMA AS database_name,
    TABLE_NAME   AS object_name,
    TABLE_TYPE   AS object_type
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'gold'
ORDER BY TABLE_SCHEMA, TABLE_NAME;


-- Q2. What columns exist in the database?
SELECT
    TABLE_SCHEMA,
    TABLE_NAME,
    COLUMN_NAME,
    ORDINAL_POSITION,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'gold'
ORDER BY TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION;


-- Q3. What columns are present in the customer dimension?
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    ORDINAL_POSITION
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'gold'
  AND TABLE_NAME = 'dim_customers'
ORDER BY ORDINAL_POSITION;


/*==============================================================
02. DIMENSIONS EXPLORATION
==============================================================*/

-- Q4. Which countries do customers come from?
SELECT DISTINCT country
FROM gold.dim_customers
ORDER BY country;
-- Result: Australia, Canada, France, Germany, United Kingdom,
--         United States (+ NULL for 337 customers).


-- Q5. Which product categories exist?
SELECT DISTINCT category
FROM gold.dim_products
ORDER BY category;
-- Result: Accessories, Bikes, Clothing, Components (+ NULL for 7 products).


-- Q6. What category, subcategory, and product hierarchy exists?
SELECT DISTINCT
    category,
    subcategory,
    product_name
FROM gold.dim_products
ORDER BY category, subcategory, product_name;


/*==============================================================
03. DATE EXPLORATION
==============================================================*/

-- Q7. What are the first and last order dates?
SELECT
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date
FROM gold.fact_sales;
-- Verified: 2010-12-29 to 2014-01-28.


-- Q8. How many years and months of order history are available?
SELECT
    TIMESTAMPDIFF(YEAR,  MIN(order_date), MAX(order_date)) AS order_range_years,
    TIMESTAMPDIFF(MONTH, MIN(order_date), MAX(order_date)) AS order_range_months
FROM gold.fact_sales;
-- Verified: 3 years / 36 months (full months elapsed).


-- Q9. What are the oldest and youngest customers' birth dates?
SELECT
    MIN(birthdate) AS oldest_birthdate,
    MAX(birthdate) AS youngest_birthdate
FROM gold.dim_customers;
-- Verified: 1916-02-10 (oldest) and 1986-06-25 (youngest).


-- Q10. What are the oldest and youngest customers' approximate ages?
SELECT
    TIMESTAMPDIFF(YEAR, MIN(birthdate), CURDATE()) AS oldest_age_approx,
    TIMESTAMPDIFF(YEAR, MAX(birthdate), CURDATE()) AS youngest_age_approx
FROM gold.dim_customers;
-- Age depends on the day you run the query (CURDATE()).


/*==============================================================
04. MEASURES EXPLORATION / KPIs
==============================================================*/

-- Q11. Total sales revenue                      (verified: 29,356,250)
SELECT SUM(sales_amount) AS total_sales
FROM gold.fact_sales;


-- Q12. Total items sold                         (verified: 60,423)
SELECT SUM(quantity) AS total_quantity
FROM gold.fact_sales;


-- Q13. Average selling price                    (verified: ~486.04)
SELECT AVG(price) AS average_price
FROM gold.fact_sales;


-- Q14. Sales rows / order-line records          (verified: 60,398)
SELECT COUNT(order_number) AS sales_rows_or_order_lines
FROM gold.fact_sales;


-- Q15. Unique orders                            (verified: 27,659)
SELECT COUNT(DISTINCT order_number) AS total_orders
FROM gold.fact_sales;


-- Q16. Products in the product dimension        (verified: 295)
SELECT COUNT(product_key) AS total_products
FROM gold.dim_products;


-- Q17. Registered customers                     (verified: 18,484)
SELECT COUNT(customer_key) AS total_customers
FROM gold.dim_customers;


-- Q18. Customers who placed an order            (verified: 18,484)
SELECT COUNT(DISTINCT customer_key) AS customers_who_ordered
FROM gold.fact_sales;


-- Q19. Consolidated KPI report
SELECT 'Total Sales' AS measure_name, SUM(sales_amount) AS measure_value
FROM gold.fact_sales
UNION ALL
SELECT 'Total Quantity', SUM(quantity)
FROM gold.fact_sales
UNION ALL
SELECT 'Average Price', AVG(price)
FROM gold.fact_sales
UNION ALL
SELECT 'Order Lines (count)', COUNT(order_number)
FROM gold.fact_sales
UNION ALL
SELECT 'Unique Orders', COUNT(DISTINCT order_number)
FROM gold.fact_sales
UNION ALL
SELECT 'Total Products', COUNT(product_key)
FROM gold.dim_products
UNION ALL
SELECT 'Total Customers', COUNT(customer_key)
FROM gold.dim_customers
UNION ALL
SELECT 'Customers Who Ordered', COUNT(DISTINCT customer_key)
FROM gold.fact_sales;


/*==============================================================
05. MAGNITUDE ANALYSIS (measure by dimension)
==============================================================*/

-- Q20. Customers by gender
-- Verified: Male 9,341 | Female 9,128 | NULL 15
SELECT
    gender,
    COUNT(customer_key) AS total_customers
FROM gold.dim_customers
GROUP BY gender
ORDER BY total_customers DESC;


-- Q21. Customers by country
-- Verified: United States 7,482 | Australia 3,591 | United Kingdom 1,913 |
--           France 1,810 | Germany 1,780 | Canada 1,571 | NULL 337
SELECT
    country,
    COUNT(customer_key) AS total_customers
FROM gold.dim_customers
GROUP BY country
ORDER BY total_customers DESC;


-- Q22. Products by category
-- Verified: Components 127 | Bikes 97 | Clothing 35 | Accessories 29 | NULL 7
SELECT
    category,
    COUNT(product_key) AS total_products
FROM gold.dim_products
GROUP BY category
ORDER BY total_products DESC;


-- Q23. Average product cost by category
-- Verified: Bikes ~949 | Components ~265 | Clothing ~25 | Accessories ~13
SELECT
    category,
    AVG(cost) AS average_cost
FROM gold.dim_products
GROUP BY category
ORDER BY average_cost DESC;


-- Q24. Total revenue by product category
-- Verified: Bikes 28,316,272 | Accessories 700,262 | Clothing 339,716
SELECT
    p.category,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
GROUP BY p.category
ORDER BY total_revenue DESC;


-- Q25. Items sold by country
SELECT
    c.country,
    SUM(f.quantity) AS total_sold_items
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
    ON f.customer_key = c.customer_key
GROUP BY c.country
ORDER BY total_sold_items DESC;


-- Q26. Total revenue generated by each customer
SELECT
    c.customer_key,
    c.first_name,
    c.last_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
    ON f.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY total_revenue DESC;


/*==============================================================
06. RANKING ANALYSIS
==============================================================*/

-- Q27. Top 5 products by revenue (combined = 6,671,859, about $6.67M)
-- Mountain-200 Black- 46    1,373,454
-- Mountain-200 Black- 42    1,363,128
-- Mountain-200 Silver- 38   1,339,394
-- Mountain-200 Silver- 46   1,301,029
-- Mountain-200 Black- 38    1,294,854
SELECT
    p.product_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
GROUP BY p.product_name
ORDER BY total_revenue DESC
LIMIT 5;


-- Q28. Bottom 5 products by revenue
-- Racing Socks- L 2,430 | Racing Socks- M 2,682 | Patch Kit/8 Patches 6,382 |
-- Bike Wash - Dissolver 7,272 | Touring Tire Tube 7,440
SELECT
    p.product_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
GROUP BY p.product_name
ORDER BY total_revenue ASC
LIMIT 5;


-- Q29. Top 5 subcategories by revenue
-- Road Bikes 14,519,438 | Mountain Bikes 9,952,254 | Touring Bikes 3,844,580 |
-- Tires and Tubes 244,634 | Helmets 225,435
SELECT
    p.subcategory,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
GROUP BY p.subcategory
ORDER BY total_revenue DESC
LIMIT 5;


-- Q30. Bottom 5 subcategories by revenue
-- Socks 5,112 | Cleaners 7,272 | Caps 19,710 | Gloves 34,320 | Vests 36,160
SELECT
    p.subcategory,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
GROUP BY p.subcategory
ORDER BY total_revenue ASC
LIMIT 5;


-- Q31. Top 5 products using ROW_NUMBER()
SELECT *
FROM
(
    SELECT
        p.product_name,
        SUM(f.sales_amount) AS total_revenue,
        ROW_NUMBER() OVER (ORDER BY SUM(f.sales_amount) DESC) AS rank_products
    FROM gold.fact_sales AS f
    LEFT JOIN gold.dim_products AS p
        ON f.product_key = p.product_key
    GROUP BY p.product_name
) AS ranked_products
WHERE rank_products <= 5
ORDER BY rank_products;


-- Q32. Top 10 customers by revenue (customer_key breaks ties)
-- 1133 Kaitlyn Henderson 13,294 | 1302 Nichole Nara 13,294 |
-- 1309 Margaret He 13,268 | 1132 Randall Dominguez 13,265 |
-- 1301 Adriana Gonzalez 13,242 | 1322 Rosa Hu 13,215 | 1125 Brandi Gill 13,195 |
-- 1308 Brad She 13,172 | 1297 Francisco Sara 13,164 | 434 Maurice Shan 12,914
SELECT
    c.customer_key,
    c.first_name,
    c.last_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
    ON f.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY total_revenue DESC, c.customer_key
LIMIT 10;


-- Q33. 3 customers with the fewest orders
-- 11,619 customers have exactly 1 order, so customer_key is added as a
-- tie-breaker to make the result reproducible.
-- Verified: 16 Chloe Young | 17 Wyatt Hill | 21 Jordan King
SELECT
    c.customer_key,
    c.first_name,
    c.last_name,
    COUNT(DISTINCT f.order_number) AS total_orders
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
    ON f.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY total_orders ASC, c.customer_key ASC
LIMIT 3;


/*==============================================================
07. RANKING EXPLORATION (window functions)
==============================================================*/

-- Q34. Rank all products by revenue: ROW_NUMBER vs RANK vs DENSE_RANK
-- 8 products share a revenue value with another product, so the three
-- functions give different numbers for them (see README).
SELECT
    p.product_name,
    SUM(f.sales_amount) AS total_revenue,
    ROW_NUMBER() OVER (ORDER BY SUM(f.sales_amount) DESC) AS row_num,
    RANK()       OVER (ORDER BY SUM(f.sales_amount) DESC) AS product_rank,
    DENSE_RANK() OVER (ORDER BY SUM(f.sales_amount) DESC) AS product_dense_rank
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
GROUP BY p.product_name
ORDER BY total_revenue DESC;


-- Q35. Top 10 products by quantity sold
-- Water Bottle - 30 oz. 4,249 | Patch Kit/8 Patches 3,191 | Mountain Tire Tube 3,096 |
-- Road Tire Tube 2,376 | Sport-100 Helmet- Red 2,230 | AWC Logo Cap 2,190 | ...
SELECT
    p.product_name,
    SUM(f.quantity) AS total_quantity
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
GROUP BY p.product_name
ORDER BY total_quantity DESC
LIMIT 10;


-- Q36. Bottom 10 products by quantity sold
SELECT
    p.product_name,
    SUM(f.quantity) AS total_quantity
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
GROUP BY p.product_name
ORDER BY total_quantity ASC
LIMIT 10;


-- Q37. Top 5 customers by number of orders (customer_key breaks ties)
SELECT
    c.customer_key,
    c.first_name,
    c.last_name,
    COUNT(DISTINCT f.order_number) AS total_orders
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
    ON f.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY total_orders DESC, c.customer_key
LIMIT 5;


-- Q38. Rank customers by revenue
SELECT
    c.customer_key,
    c.first_name,
    c.last_name,
    SUM(f.sales_amount) AS total_revenue,
    ROW_NUMBER() OVER (ORDER BY SUM(f.sales_amount) DESC) AS customer_rank
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
    ON f.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY total_revenue DESC;


-- Q39. Top 3 products in each category
-- Accessories: Sport-100 Helmet- Red / Blue / Black
-- Bikes:       Mountain-200 Black- 46 / Black- 42 / Silver- 38
-- Clothing:    Women's Mountain Shorts- L / M, Long-Sleeve Logo Jersey- L
WITH ranked_products AS
(
    SELECT
        p.category,
        p.product_name,
        SUM(f.sales_amount) AS total_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY p.category
            ORDER BY SUM(f.sales_amount) DESC
        ) AS rank_in_category
    FROM gold.fact_sales AS f
    LEFT JOIN gold.dim_products AS p
        ON f.product_key = p.product_key
    GROUP BY p.category, p.product_name
)
SELECT
    category,
    product_name,
    total_revenue,
    rank_in_category
FROM ranked_products
WHERE rank_in_category <= 3
ORDER BY category, rank_in_category;


-- Q40. Top 5 countries by revenue
-- United States 9,162,327 | Australia 9,060,172 | United Kingdom 3,391,376 |
-- Germany 2,894,066 | France 2,643,751
-- (The NULL-country group, 226,820, sits at the bottom and is excluded here.)
SELECT
    c.country,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
    ON f.customer_key = c.customer_key
WHERE c.country IS NOT NULL
GROUP BY c.country
ORDER BY total_revenue DESC
LIMIT 5;


-- Q41. Bottom 5 countries by revenue
-- Canada 1,977,738 | France 2,643,751 | Germany 2,894,066 |
-- United Kingdom 3,391,376 | Australia 9,060,172
-- Rows with an unknown (NULL) country are excluded, otherwise the NULL group
-- (226,820) would show up as the "lowest country".
SELECT
    c.country,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
    ON f.customer_key = c.customer_key
WHERE c.country IS NOT NULL
GROUP BY c.country
ORDER BY total_revenue ASC
LIMIT 5;


/*
================================================================
END OF PROJECT: SQL EXPLORATORY DATA ANALYSIS (EDA)
================================================================
*/
