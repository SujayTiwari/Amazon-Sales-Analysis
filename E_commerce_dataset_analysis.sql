-- Create and use database
CREATE DATABASE amazon_analysis;
USE amazon_analysis;

-- Table creation
CREATE TABLE sales_report (
    id INT,
    order_id VARCHAR(20),
    order_date DATETIME,
    status VARCHAR(20),
    fulfilment VARCHAR(20),
    sales_channel VARCHAR(20),
    ship_service_level VARCHAR(30),
    style VARCHAR(20),
    sku VARCHAR(20),
    category VARCHAR(30),
    size VARCHAR(10),
    asin VARCHAR(20),
    courier_status VARCHAR(20),
    qty INT,
    currency VARCHAR(10),
    amount DECIMAL(10,2),
    ship_city VARCHAR(50),
    ship_state VARCHAR(50),
    ship_postal_code VARCHAR(20),
    ship_country VARCHAR(50),
    promotion_ids VARCHAR(50),
    b2b VARCHAR(5),
    fulfilled_by VARCHAR(20)
);

-- Basic exploration
SELECT * FROM sales_report LIMIT 10;
SELECT COUNT(*) FROM sales_report;
SELECT MIN(order_date) AS start_date, MAX(order_date) AS end_date FROM sales_report;

-- Check for duplicates
SELECT order_id, COUNT(*) AS occurrences
FROM sales_report
GROUP BY order_id
HAVING COUNT(*) > 1;

/* === E-COMMERCE SALES PROJECT === */

/*
1. Sales Performance
2. Product Insights
3. Fulfillment & Shipping
4. Promotion & Channel Effectiveness
5. Customer Segmentation
*/

/* === 1. SALES PERFORMANCE === */

-- Total orders and revenue
SELECT COUNT(DISTINCT order_id) AS total_orders,
       SUM(amount) AS total_revenue
FROM sales_report;

-- Average Order Value (AOV)
SELECT ROUND(SUM(amount) / COUNT(DISTINCT order_id), 2) AS avg_order_value
FROM sales_report;

-- Revenue by category
SELECT category, FORMAT(SUM(amount), 0) AS total_revenue
FROM sales_report
GROUP BY category
ORDER BY total_revenue DESC;

-- Monthly sales trend
SELECT DATE_FORMAT(order_date, '%Y-%m') AS month,
       FORMAT(SUM(amount), 0) AS total_revenue
FROM sales_report
GROUP BY month
ORDER BY month;

-- Seasonality pattern
SELECT MONTH(order_date) AS month_number,
       DATE_FORMAT(order_date, '%M') AS month_name,
       YEAR(order_date) AS year,
       SUM(amount) AS total_sales
FROM sales_report
GROUP BY year, month_number, month_name
ORDER BY month_number, year;

/* === 2. PRODUCT INSIGHTS === */

-- Top 10 best-selling SKUs
SELECT sku, SUM(amount) AS total_amount,
       ROW_NUMBER() OVER (ORDER BY SUM(amount) DESC) AS top_rank
FROM sales_report
GROUP BY sku
LIMIT 10;

-- SKUs with highest return rates
SELECT sku,
       COUNT(*) AS total_orders,
       SUM(CASE WHEN courier_status = 'Returned' THEN 1 ELSE 0 END) AS total_returns,
       ROUND(SUM(CASE WHEN courier_status = 'Returned' THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS return_rate
FROM sales_report
GROUP BY sku
ORDER BY total_returns DESC;

-- Least sold sizes per category
SELECT category, size,
       SUM(qty) AS total_units_sold,
       SUM(amount) AS total_sales
FROM sales_report
GROUP BY category, size
ORDER BY category, total_units_sold ASC;

-- Most popular styles per category
SELECT category, style, COUNT(*) AS total,
       RANK() OVER (PARTITION BY category ORDER BY COUNT(*) DESC) AS rank_within_category
FROM sales_report
GROUP BY category, style;

-- Top styles by quantity
SELECT style, SUM(qty) AS total_qty,
       RANK() OVER (ORDER BY SUM(qty) DESC) AS rank_by_qty
FROM sales_report
GROUP BY style;

-- Orders with quantity > average
SELECT order_id, qty
FROM sales_report
WHERE qty > (SELECT AVG(qty) FROM sales_report);

/* === 3. FULFILLMENT & SHIPPING === */

-- Orders fulfilled by Amazon vs Seller
SELECT COUNT(*) AS total_orders,
       SUM(CASE WHEN fulfilled_by = 'Amazon' THEN 1 ELSE 0 END) AS fulfilled_by_amazon,
       SUM(CASE WHEN fulfilled_by = 'Seller' THEN 1 ELSE 0 END) AS fulfilled_by_seller
FROM sales_report;

-- Avg delivery quantity per shipping level
SELECT ship_service_level,
       COUNT(*) AS total_orders,
       ROUND(AVG(qty)) AS avg_delivery_qty
FROM sales_report
GROUP BY ship_service_level;

-- Cities with most returns
SELECT ship_city,
       SUM(CASE WHEN courier_status = 'Returned' THEN 1 ELSE 0 END) AS total_returns
FROM sales_report
GROUP BY ship_city
ORDER BY total_returns DESC;

-- % of same-day shipping orders
SELECT CONCAT(ROUND(same_day_orders / total_orders * 100, 2), '%') AS same_day_pct
FROM (
  SELECT COUNT(*) AS total_orders,
         SUM(CASE WHEN ship_service_level = 'Same day' THEN 1 ELSE 0 END) AS same_day_orders
  FROM sales_report
) AS summary;

-- Courier status trends by state
SELECT ship_state, courier_status, COUNT(*) AS total,
       RANK() OVER (PARTITION BY ship_state ORDER BY COUNT(*) DESC) AS rank_in_state
FROM sales_report
GROUP BY ship_state, courier_status;

/* === 4. CHANNEL & PROMOTION EFFECTIVENESS === */

-- Sales by channel
SELECT sales_channel, FORMAT(SUM(amount), 0) AS total_sales,
       COUNT(*) AS total_orders
FROM sales_report
GROUP BY sales_channel;

-- Revenue from B2B orders
SELECT FORMAT(SUM(amount), 0) AS b2b_revenue
FROM sales_report
WHERE b2b = 'Yes';

-- % of promo code usage
WITH promo_summary AS (
  SELECT COUNT(*) AS total_orders,
         SUM(CASE WHEN promotion_ids IS NOT NULL AND promotion_ids != '' THEN 1 ELSE 0 END) AS promo_used
  FROM sales_report
)
SELECT *, CONCAT(ROUND(promo_used / total_orders * 100, 2), '%') AS promo_pct
FROM promo_summary;

-- Most used promotion ID
SELECT promotion_ids, COUNT(*) AS usage_count
FROM sales_report
GROUP BY promotion_ids
ORDER BY usage_count DESC
LIMIT 1;

/* === 5. CUSTOMER SEGMENTATION === */

-- Cities with highest repeat orders
SELECT ship_city, COUNT(*) AS repeat_orders
FROM sales_report
GROUP BY ship_city
ORDER BY repeat_orders DESC
LIMIT 3;

-- Avg quantity per order by category
SELECT category,
       COUNT(DISTINCT order_id) AS total_orders,
       ROUND(AVG(order_qty), 0) AS avg_qty
FROM (
    SELECT category, order_id, SUM(qty) AS order_qty
    FROM sales_report
    GROUP BY category, order_id
) AS sub
GROUP BY category
ORDER BY category;

-- Most ordered ASINs
SELECT asin, COUNT(*) AS total_orders
FROM sales_report
GROUP BY asin;

-- Customer behavior by country
SELECT ship_country, fulfilled_by,
       COUNT(*) AS total_orders,
       SUM(qty) AS total_quantity,
       FORMAT(SUM(amount), 0) AS total_amount,
       SUM(CASE WHEN promotion_ids IS NOT NULL AND promotion_ids != '' THEN 1 ELSE 0 END) AS promo_usage_count
FROM sales_report
GROUP BY ship_country, fulfilled_by
ORDER BY ship_country, total_orders DESC;

-- Month over Month (MOM) growth
SELECT 
    DATE_FORMAT(order_date, '%Y-%m') AS month,
    SUM(amount) AS monthly_sales,
    LAG(SUM(amount)) OVER (ORDER BY DATE_FORMAT(order_date, '%Y-%m')) AS prev_month_sales,
    ROUND((SUM(amount) - LAG(SUM(amount)) OVER (ORDER BY DATE_FORMAT(order_date, '%Y-%m'))) / 
          LAG(SUM(amount)) OVER (ORDER BY DATE_FORMAT(order_date, '%Y-%m')) * 100, 2) AS mom_growth
FROM sales_report
GROUP BY DATE_FORMAT(order_date, '%Y-%m');



