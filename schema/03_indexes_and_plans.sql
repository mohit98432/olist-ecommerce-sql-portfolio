-- Compare the delivery-date lookup plan before and after indexing.
USE olist_resume_analytics;

-- Run this EXPLAIN first and note the access type and estimated rows.
EXPLAIN SELECT order_id, customer_id, order_date
FROM orders
WHERE order_date >= '2025-01-01' AND order_date < '2025-04-01'
ORDER BY order_date;

CREATE INDEX idx_orders_date_status ON orders(order_date, order_status);
CREATE INDEX idx_order_items_product ON order_items(product_id);
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_customers_state ON customers(state);

-- Run the same plan again. MySQL can use the leading order_date index column.
EXPLAIN SELECT order_id, customer_id, order_date
FROM orders
WHERE order_date >= '2025-01-01' AND order_date < '2025-04-01'
ORDER BY order_date;
