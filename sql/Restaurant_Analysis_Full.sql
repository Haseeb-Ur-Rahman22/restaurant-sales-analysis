/*==============================================================
  PROJECT : Restaurant Sales & Operations Analysis
  STAGE   : EDA, Modeling and Analysis
  SOURCE  : Restaurant_Orders.csv, Restaurant_items.csv (1,000,000 rows)
  PURPOSE : Look at the data, check it is clean, build a view,
            then answer the business questions.
  NOTES   : earned revenue = complete + refunded
            lost revenue   = cancelled only
            Demonstration dataset (realistic simulation).
==============================================================*/

USE Restaurant_Project;
GO


/*========================  PART 1: EDA  ========================*/

-- How many rows in each table?
SELECT 'Restaurant_Orders' AS table_name, COUNT(*) AS row_count FROM dbo.Restaurant_Orders
UNION ALL
SELECT 'Restaurant_items',  COUNT(*) FROM dbo.Restaurant_items;

-- How many columns in each table?
SELECT TABLE_NAME, COUNT(*) AS column_count
FROM   INFORMATION_SCHEMA.COLUMNS
WHERE  TABLE_NAME IN ('Restaurant_Orders','Restaurant_items')
GROUP BY TABLE_NAME;

-- What is the data type of each column?
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE
FROM   INFORMATION_SCHEMA.COLUMNS
WHERE  TABLE_NAME IN ('Restaurant_Orders','Restaurant_items')
ORDER  BY TABLE_NAME, ORDINAL_POSITION;

-- Look at a few sample rows to see the data
SELECT TOP 10 * FROM dbo.Restaurant_Orders;
SELECT TOP 10 * FROM dbo.Restaurant_items;

-- What does one row mean? Count line items vs orders
SELECT
    COUNT(*)                 AS total_line_items,
    COUNT(DISTINCT order_id) AS distinct_orders
FROM dbo.Restaurant_Orders;

-- Count the values in each text column (look for typos or odd values)
SELECT Payment_Method, COUNT(*) AS n
FROM dbo.Restaurant_Orders GROUP BY Payment_Method ORDER BY n DESC;

SELECT Platform, COUNT(*) AS n
FROM dbo.Restaurant_Orders GROUP BY Platform ORDER BY n DESC;

SELECT Branch, COUNT(*) AS n
FROM dbo.Restaurant_Orders GROUP BY Branch ORDER BY n DESC;

SELECT Order_Status, COUNT(*) AS n
FROM dbo.Restaurant_Orders GROUP BY Order_Status ORDER BY n DESC;

-- Check the Quantity column: smallest, biggest, average
SELECT
    MIN(Quantity) AS min_qty,
    MAX(Quantity) AS max_qty,
    AVG(CAST(Quantity AS decimal(10,2))) AS avg_qty
FROM dbo.Restaurant_Orders;

-- See how many times each quantity value appears
SELECT Quantity, COUNT(*) AS n
FROM dbo.Restaurant_Orders
GROUP BY Quantity
ORDER BY Quantity;

-- Check the date range and how many days are covered
SELECT
    MIN(order_date) AS earliest_date,
    MAX(order_date) AS latest_date,
    COUNT(DISTINCT order_date) AS distinct_days
FROM dbo.Restaurant_Orders;

-- Count orders in each year
SELECT YEAR(order_date) AS order_year, COUNT(*) AS n
FROM dbo.Restaurant_Orders
GROUP BY YEAR(order_date)
ORDER BY order_year;

-- Check every column for missing or blank values
SELECT
  SUM(CASE WHEN order_details_id IS NULL THEN 1 ELSE 0 END) AS null_details_id,
  SUM(CASE WHEN order_id  IS NULL THEN 1 ELSE 0 END)        AS null_order_id,
  SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END)       AS null_order_date,
  SUM(CASE WHEN order_time IS NULL THEN 1 ELSE 0 END)       AS null_order_time,
  SUM(CASE WHEN item_id   IS NULL THEN 1 ELSE 0 END)        AS null_item_id,
  SUM(CASE WHEN Payment_Method IS NULL OR LTRIM(RTRIM(Payment_Method))='' THEN 1 ELSE 0 END) AS blank_payment,
  SUM(CASE WHEN Platform IS NULL OR LTRIM(RTRIM(Platform))='' THEN 1 ELSE 0 END) AS blank_platform,
  SUM(CASE WHEN Branch   IS NULL OR LTRIM(RTRIM(Branch))=''   THEN 1 ELSE 0 END) AS blank_branch,
  SUM(CASE WHEN Quantity IS NULL THEN 1 ELSE 0 END)         AS null_quantity,
  SUM(CASE WHEN Order_Status IS NULL OR LTRIM(RTRIM(Order_Status))='' THEN 1 ELSE 0 END) AS blank_status
FROM dbo.Restaurant_Orders;

-- Check the key is unique (order_details_id should never repeat)
SELECT order_details_id, COUNT(*) AS times_seen
FROM dbo.Restaurant_Orders
GROUP BY order_details_id
HAVING COUNT(*) > 1;

-- Check for hidden characters (byte length should match character length)
SELECT DISTINCT
    Order_Status,
    LEN(Order_Status)        AS char_count,
    DATALENGTH(Order_Status) AS byte_length
FROM dbo.Restaurant_Orders;

-- Join check A: any item in Orders that is NOT in the menu? (should be empty)
SELECT DISTINCT o.item_id
FROM dbo.Restaurant_Orders o
LEFT JOIN dbo.Restaurant_items i ON o.item_id = i.menu_item_id
WHERE i.menu_item_id IS NULL;

-- Join check B: any menu item that was never ordered?
SELECT i.menu_item_id, i.item_name, i.category
FROM dbo.Restaurant_items i
LEFT JOIN dbo.Restaurant_Orders o ON i.menu_item_id = o.item_id
WHERE o.item_id IS NULL;


/*======================  PART 2: MODELING  ======================*/
GO
-- Build one ready-to-use table: orders joined with menu, plus sales amount
CREATE OR ALTER VIEW vw_restaurant_sales AS
SELECT
    o.order_details_id,
    o.order_id,
    o.order_date,
    o.order_time,
    o.item_id,
    i.item_name,
    i.category,
    i.price,
    o.Quantity,
    (o.Quantity * i.price)  AS sales_amount,   -- revenue for this line (qty x price)
    o.Payment_Method,
    o.Platform,
    o.Branch,
    o.Order_Status
FROM dbo.Restaurant_Orders o
INNER JOIN dbo.Restaurant_items i
        ON o.item_id = i.menu_item_id;
GO

-- Check the view works, row count should match Orders (1,000,000)
SELECT TOP 10 * FROM vw_restaurant_sales;
SELECT COUNT(*) AS rows_in_view FROM vw_restaurant_sales;


/*======================  PART 3: ANALYSIS  ======================*/

-- Main numbers: total revenue, earned, lost, and lost percent
SELECT
    COUNT(*)                          AS total_line_items,
    COUNT(DISTINCT order_id)          AS total_orders,
    SUM(sales_amount)                 AS gross_revenue,
    SUM(CASE WHEN Order_Status IN ('complete','refunded') THEN sales_amount ELSE 0 END) AS earned_revenue,
    SUM(CASE WHEN Order_Status = 'cancelled' THEN sales_amount ELSE 0 END)               AS lost_revenue,
    CAST(100.0 * SUM(CASE WHEN Order_Status = 'cancelled' THEN sales_amount ELSE 0 END)
              / SUM(sales_amount) AS decimal(5,2))                                       AS lost_revenue_pct
FROM vw_restaurant_sales;

-- Average value of one order (earned orders only)
SELECT
    CAST(SUM(sales_amount) * 1.0 / COUNT(DISTINCT order_id) AS decimal(10,2)) AS avg_order_value
FROM vw_restaurant_sales
WHERE Order_Status IN ('complete','refunded');

-- Revenue for each month (to see the trend over time)
SELECT
    YEAR(order_date)  AS order_year,
    MONTH(order_date) AS order_month,
    SUM(CASE WHEN Order_Status IN ('complete','refunded') THEN sales_amount ELSE 0 END) AS earned_revenue,
    COUNT(DISTINCT order_id) AS orders
FROM vw_restaurant_sales
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY order_year, order_month;

-- Revenue and cancellations for each branch
SELECT
    Branch,
    COUNT(DISTINCT order_id) AS orders,
    SUM(CASE WHEN Order_Status IN ('complete','refunded') THEN sales_amount ELSE 0 END) AS earned_revenue,
    SUM(CASE WHEN Order_Status = 'cancelled' THEN sales_amount ELSE 0 END)               AS lost_revenue,
    CAST(100.0 * SUM(CASE WHEN Order_Status = 'cancelled' THEN sales_amount ELSE 0 END)
              / SUM(sales_amount) AS decimal(5,2))                                       AS cancel_pct
FROM vw_restaurant_sales
GROUP BY Branch
ORDER BY earned_revenue DESC;

-- Menu by category: units and revenue (both counted the same earned way)
SELECT
    category,
    SUM(CASE WHEN Order_Status IN ('complete','refunded') THEN Quantity     ELSE 0 END) AS units_sold,
    SUM(CASE WHEN Order_Status IN ('complete','refunded') THEN sales_amount ELSE 0 END) AS earned_revenue
FROM vw_restaurant_sales
GROUP BY category
ORDER BY earned_revenue DESC;

-- Menu by item: units and revenue (both counted the same earned way)
SELECT
    item_name,
    category,
    SUM(CASE WHEN Order_Status IN ('complete','refunded') THEN Quantity     ELSE 0 END) AS units_sold,
    SUM(CASE WHEN Order_Status IN ('complete','refunded') THEN sales_amount ELSE 0 END) AS earned_revenue
FROM vw_restaurant_sales
GROUP BY item_name, category
ORDER BY earned_revenue DESC;

-- Each platform: revenue, average line value, and cancel percent
SELECT
    Platform,
    COUNT(DISTINCT order_id) AS orders,
    SUM(CASE WHEN Order_Status IN ('complete','refunded') THEN sales_amount ELSE 0 END) AS earned_revenue,
    CAST(AVG(CASE WHEN Order_Status IN ('complete','refunded') THEN sales_amount END) AS decimal(10,2)) AS avg_line_value,
    CAST(100.0 * SUM(CASE WHEN Order_Status = 'cancelled' THEN sales_amount ELSE 0 END)
              / SUM(sales_amount) AS decimal(5,2)) AS cancel_pct
FROM vw_restaurant_sales
GROUP BY Platform
ORDER BY earned_revenue DESC;

-- Cancel rate by platform and payment method (find where cancels happen)
SELECT
    Platform,
    Payment_Method,
    COUNT(*) AS lines,
    SUM(CASE WHEN Order_Status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled_lines,
    CAST(100.0 * SUM(CASE WHEN Order_Status = 'cancelled' THEN 1 ELSE 0 END) / COUNT(*) AS decimal(5,2)) AS cancel_rate
FROM vw_restaurant_sales
GROUP BY Platform, Payment_Method
ORDER BY cancel_rate DESC;

-- Cancel rate by hour of day (check if time affects cancels)
SELECT
    DATEPART(HOUR, order_time) AS hour_of_day,
    COUNT(*) AS lines,
    SUM(CASE WHEN Order_Status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled_lines,
    CAST(100.0 * SUM(CASE WHEN Order_Status = 'cancelled' THEN 1 ELSE 0 END) / COUNT(*) AS decimal(5,2)) AS cancel_rate
FROM vw_restaurant_sales
GROUP BY DATEPART(HOUR, order_time)
ORDER BY hour_of_day;
