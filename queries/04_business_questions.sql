-- 28 business questions | MySQL 8.0
USE olist_resume_analytics;

-- 01. How many rows were loaded into each core entity?
SELECT 'customers' entity, COUNT(*) rows_loaded FROM customers UNION ALL
SELECT 'products', COUNT(*) FROM products UNION ALL SELECT 'orders', COUNT(*) FROM orders UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items UNION ALL SELECT 'payments', COUNT(*) FROM payments UNION ALL
SELECT 'shipments', COUNT(*) FROM shipments;

-- 02. What is the order-status mix?
SELECT order_status, COUNT(*) orders, ROUND(100*COUNT(*)/(SELECT COUNT(*) FROM orders),1) pct
FROM orders GROUP BY order_status ORDER BY orders DESC;

-- 03. How much revenue and how many units came from each order status?
SELECT order_status, COUNT(*) orders, ROUND(SUM(merchandise_revenue),2) revenue, SUM(units) units
FROM v_order_revenue GROUP BY order_status ORDER BY revenue DESC;

-- 04. Which states have the most customers?
SELECT state, COUNT(*) customers FROM customers GROUP BY state ORDER BY customers DESC;

-- 05. What is average order value by state for delivered orders?
SELECT c.state, COUNT(*) delivered_orders,
       ROUND(AVG(r.merchandise_revenue),2) avg_order_value
FROM customers c JOIN v_order_revenue r USING(customer_id)
WHERE r.order_status='delivered' GROUP BY c.state ORDER BY avg_order_value DESC;

-- 06. Which categories generate the most delivered revenue?
SELECT c.category_name, ROUND(SUM(i.quantity*i.unit_price-i.discount_amount),2) revenue
FROM categories c JOIN products p USING(category_id) JOIN order_items i USING(product_id)
JOIN orders o USING(order_id) WHERE o.order_status='delivered'
GROUP BY c.category_name ORDER BY revenue DESC;

-- 07. What are the top 10 products by delivered units?
SELECT p.product_name, SUM(i.quantity) units_sold
FROM products p JOIN order_items i USING(product_id) JOIN orders o USING(order_id)
WHERE o.order_status='delivered' GROUP BY p.product_id,p.product_name
ORDER BY units_sold DESC LIMIT 10;

-- 08. Which categories have revenue above the portfolio-wide category average?
WITH category_revenue AS (
 SELECT c.category_id,c.category_name,SUM(i.quantity*i.unit_price-i.discount_amount) revenue
 FROM categories c JOIN products p USING(category_id) JOIN order_items i USING(product_id)
 JOIN orders o USING(order_id) WHERE o.order_status='delivered' GROUP BY c.category_id,c.category_name
)
SELECT category_name, ROUND(revenue,2) revenue FROM category_revenue
WHERE revenue > (SELECT AVG(revenue) FROM category_revenue) ORDER BY revenue DESC;

-- 09. Which customers have spent more than the average customer lifetime spend?
WITH customer_spend AS (
 SELECT c.customer_id,c.state,SUM(r.merchandise_revenue) spend
 FROM customers c JOIN v_order_revenue r USING(customer_id)
 WHERE r.order_status='delivered' GROUP BY c.customer_id,c.state
)
SELECT customer_id,state,ROUND(spend,2) spend FROM customer_spend
WHERE spend > (SELECT AVG(spend) FROM customer_spend) ORDER BY spend DESC LIMIT 20;

-- 10. Which orders have a payment amount that differs from the line total?
SELECT p.order_id,p.amount,ROUND(r.merchandise_revenue,2) line_total
FROM payments p JOIN v_order_revenue r USING(order_id)
WHERE ABS(p.amount-r.merchandise_revenue)>0.01;

-- 11. What share of payments use each method?
SELECT payment_method,COUNT(*) payments,ROUND(100*COUNT(*)/(SELECT COUNT(*) FROM payments),1) pct
FROM payments GROUP BY payment_method ORDER BY payments DESC;

-- 12. What is monthly delivered revenue and order volume?
SELECT sales_month,delivered_orders,ROUND(gross_merchandise_revenue,2) revenue,units_sold
FROM v_monthly_sales ORDER BY sales_month;

-- 13. Which months grew or declined versus the previous month? (LAG)
WITH monthly AS (SELECT STR_TO_DATE(sales_month,'%Y-%m-%d') month_start,gross_merchandise_revenue
                 FROM v_monthly_sales)
SELECT month_start,ROUND(gross_merchandise_revenue,2) revenue,
       ROUND(LAG(gross_merchandise_revenue) OVER(ORDER BY month_start),2) prior_month,
       ROUND(gross_merchandise_revenue-LAG(gross_merchandise_revenue) OVER(ORDER BY month_start),2) change_value
FROM monthly ORDER BY month_start;

-- 14. Rank states by delivered revenue (RANK).
WITH state_sales AS (
 SELECT c.state,SUM(r.merchandise_revenue) revenue FROM customers c JOIN v_order_revenue r USING(customer_id)
 WHERE r.order_status='delivered' GROUP BY c.state
)
SELECT state,ROUND(revenue,2) revenue,RANK() OVER(ORDER BY revenue DESC) revenue_rank
FROM state_sales ORDER BY revenue_rank;

-- 15. What is the top product in each category? (ROW_NUMBER)
WITH product_sales AS (
 SELECT c.category_name,p.product_name,SUM(i.quantity*i.unit_price-i.discount_amount) revenue
 FROM categories c JOIN products p USING(category_id) JOIN order_items i USING(product_id)
 JOIN orders o USING(order_id) WHERE o.order_status='delivered'
 GROUP BY c.category_name,p.product_id,p.product_name
), ranked AS (
 SELECT *,ROW_NUMBER() OVER(PARTITION BY category_name ORDER BY revenue DESC,product_name) rn FROM product_sales
)
SELECT category_name,product_name,ROUND(revenue,2) revenue FROM ranked WHERE rn=1 ORDER BY category_name;

-- 16. What is the running total of delivered revenue by month?
SELECT sales_month,ROUND(gross_merchandise_revenue,2) month_revenue,
       ROUND(SUM(gross_merchandise_revenue) OVER(ORDER BY sales_month),2) running_revenue
FROM v_monthly_sales ORDER BY sales_month;

-- 17. How many days does delivery take on average, by customer state?
SELECT c.state,ROUND(AVG(DATEDIFF(s.delivered_at,o.order_date)),1) avg_days_to_delivery
FROM customers c JOIN orders o USING(customer_id) JOIN shipments s USING(order_id)
WHERE s.delivered_at IS NOT NULL GROUP BY c.state ORDER BY avg_days_to_delivery DESC;

-- 18. What percentage of delivered shipments arrived after estimate?
SELECT COUNT(*) late_deliveries,
       ROUND(100*COUNT(*)/(SELECT COUNT(*) FROM shipments WHERE delivered_at IS NOT NULL),1) late_pct
FROM shipments WHERE delivered_at IS NOT NULL AND DATE(delivered_at)>estimated_delivery;

-- 19. Which products have never been sold?
SELECT p.product_id,p.product_name FROM products p
WHERE NOT EXISTS (SELECT 1 FROM order_items i WHERE i.product_id=p.product_id);

-- 20. Which customers have placed multiple orders?
SELECT c.customer_id,c.state,COUNT(o.order_id) order_count
FROM customers c JOIN orders o USING(customer_id)
GROUP BY c.customer_id,c.state HAVING COUNT(o.order_id)>1 ORDER BY order_count DESC LIMIT 20;

-- 21. How many delivered orders and what revenue per customer cohort month?
SELECT DATE_FORMAT(c.created_at,'%Y-%m') cohort_month,COUNT(DISTINCT c.customer_id) customers,
       COUNT(o.order_id) delivered_orders,ROUND(SUM(r.merchandise_revenue),2) revenue
FROM customers c LEFT JOIN orders o ON o.customer_id=c.customer_id AND o.order_status='delivered'
LEFT JOIN v_order_revenue r ON r.order_id=o.order_id
GROUP BY cohort_month ORDER BY cohort_month;

-- 22. Which months have above-average delivered order value?
WITH monthly_aov AS (
 SELECT DATE_FORMAT(order_date,'%Y-%m') month_key,AVG(merchandise_revenue) aov
 FROM v_order_revenue WHERE order_status='delivered' GROUP BY DATE_FORMAT(order_date,'%Y-%m')
)
SELECT month_key,ROUND(aov,2) aov FROM monthly_aov
WHERE aov>(SELECT AVG(aov) FROM monthly_aov) ORDER BY aov DESC;

-- 23. How many customers made another purchase within 90 days of their previous one?
WITH ordered AS (
 SELECT customer_id,order_date,LAG(order_date) OVER(PARTITION BY customer_id ORDER BY order_date) previous_order
 FROM orders WHERE order_status='delivered'
)
SELECT COUNT(DISTINCT customer_id) customers_with_repeat_within_90_days
FROM ordered WHERE previous_order IS NOT NULL AND DATEDIFF(order_date,previous_order)<=90;

-- 24. What is the average discount rate by category?
SELECT c.category_name,ROUND(SUM(i.discount_amount)/NULLIF(SUM(i.quantity*i.unit_price),0)*100,2) discount_pct
FROM categories c JOIN products p USING(category_id) JOIN order_items i USING(product_id)
GROUP BY c.category_name ORDER BY discount_pct DESC;

-- 25. What is the delivered revenue per payment method?
SELECT p.payment_method,COUNT(*) delivered_orders,ROUND(SUM(r.merchandise_revenue),2) revenue
FROM payments p JOIN v_order_revenue r USING(order_id)
WHERE r.order_status='delivered' GROUP BY p.payment_method ORDER BY revenue DESC;

-- 26. What is the order value distribution by quartile? (NTILE)
WITH ranked AS (
 SELECT order_id,merchandise_revenue,NTILE(4) OVER(ORDER BY merchandise_revenue) value_quartile
 FROM v_order_revenue WHERE order_status='delivered'
)
SELECT value_quartile,COUNT(*) orders,ROUND(MIN(merchandise_revenue),2) min_value,
       ROUND(MAX(merchandise_revenue),2) max_value,ROUND(AVG(merchandise_revenue),2) avg_value
FROM ranked GROUP BY value_quartile ORDER BY value_quartile;

-- 27. Which state/category pairs generate above-average revenue?
WITH state_category AS (
 SELECT c.state,cat.category_name,SUM(i.quantity*i.unit_price-i.discount_amount) revenue
 FROM customers c JOIN orders o USING(customer_id) JOIN order_items i USING(order_id)
 JOIN products p USING(product_id) JOIN categories cat USING(category_id)
 WHERE o.order_status='delivered' GROUP BY c.state,cat.category_name
)
SELECT state,category_name,ROUND(revenue,2) revenue FROM state_category
WHERE revenue>(SELECT AVG(revenue) FROM state_category) ORDER BY revenue DESC LIMIT 20;

-- 28. What is sales by state for a user-selected date range? (stored procedure)
CALL sp_sales_by_state('2025-01-01','2025-12-31');
