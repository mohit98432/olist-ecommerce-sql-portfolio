-- Deterministic synthetic marketplace dataset inspired by Olist's business domain.
-- 1,000 customers, 1,200 orders, 60 products, 3,000+ order lines, 1,200 payments, 1,200 shipments.
USE olist_resume_analytics;
SET SESSION cte_max_recursion_depth = 2000;
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE shipments;
TRUNCATE TABLE payments;
TRUNCATE TABLE order_items;
TRUNCATE TABLE orders;
TRUNCATE TABLE products;
TRUNCATE TABLE categories;
TRUNCATE TABLE customers;
SET FOREIGN_KEY_CHECKS = 1;

INSERT INTO categories (category_id, category_name) VALUES
(1,'bed_bath'),(2,'computers'),(3,'fashion'),(4,'health_beauty'),
(5,'home_kitchen'),(6,'housewares'),(7,'office'),(8,'sports'),
(9,'toys'),(10,'electronics'),(11,'books'),(12,'pet_supplies');

INSERT INTO customers (customer_id, customer_unique_id, city, state, created_at)
WITH RECURSIVE seq AS (
  SELECT 1 AS n UNION ALL SELECT n+1 FROM seq WHERE n < 1000
)
SELECT n, LPAD(HEX(n * 7919), 32, '0'),
       ELT(1 + MOD(n,10),'sao paulo','rio de janeiro','belo horizonte','curitiba','recife','porto alegre','salvador','brasilia','campinas','goiania'),
       ELT(1 + MOD(n,8),'SP','RJ','MG','PR','PE','RS','BA','DF'),
       TIMESTAMP('2023-01-01 09:00:00') + INTERVAL MOD(n * 13, 600) DAY
FROM seq;

INSERT INTO products (product_id, category_id, product_name, list_price, weight_grams)
WITH RECURSIVE seq AS (
  SELECT 1 AS n UNION ALL SELECT n+1 FROM seq WHERE n < 60
)
SELECT n, 1 + MOD(n-1,12), CONCAT('Marketplace item ', LPAD(n,3,'0')),
       ROUND(12 + MOD(n * 137, 1800) / 10, 2), 150 + MOD(n * 83, 8000)
FROM seq;

INSERT INTO orders (order_id, customer_id, order_date, order_status)
WITH RECURSIVE seq AS (
  SELECT 1 AS n UNION ALL SELECT n+1 FROM seq WHERE n < 1200
)
SELECT n, 1 + MOD(n-1,1000),
       TIMESTAMP('2024-01-01 08:00:00') + INTERVAL MOD(n * 17, 730) DAY + INTERVAL MOD(n,12) HOUR,
       CASE WHEN MOD(n,25)=0 THEN 'canceled'
            WHEN MOD(n,10)=0 THEN 'processing'
            WHEN MOD(n,4)=0 THEN 'shipped' ELSE 'delivered' END
FROM seq;

INSERT INTO order_items (order_id, item_number, product_id, quantity, unit_price, discount_amount)
SELECT o.order_id, li.item_number,
       1 + MOD(o.order_id * 7 + li.item_number * 11,60),
       1 + MOD(o.order_id + li.item_number,4),
       p.list_price,
       CASE WHEN MOD(o.order_id + li.item_number,5)=0 THEN ROUND(p.list_price * 0.05,2) ELSE 0 END
FROM orders o
CROSS JOIN (SELECT 1 AS item_number UNION ALL SELECT 2 UNION ALL SELECT 3) li
CROSS JOIN products p
WHERE p.product_id = 1 + MOD(o.order_id * 7 + li.item_number * 11,60);

INSERT INTO payments (payment_id, order_id, payment_method, payment_status, amount, paid_at)
SELECT o.order_id, o.order_id,
       ELT(1 + MOD(o.order_id,4),'credit_card','boleto','debit_card','voucher'),
       CASE WHEN o.order_status='canceled' THEN 'refunded'
            WHEN o.order_status='processing' THEN 'pending' ELSE 'paid' END,
       COALESCE(SUM(i.quantity * i.unit_price - i.discount_amount),0),
       CASE WHEN o.order_status='canceled' THEN NULL ELSE o.order_date + INTERVAL 1 DAY END
FROM orders o LEFT JOIN order_items i ON i.order_id=o.order_id
GROUP BY o.order_id, o.order_status, o.order_date;

INSERT INTO shipments (shipment_id, order_id, shipped_at, delivered_at, estimated_delivery)
SELECT o.order_id, o.order_id,
       CASE WHEN o.order_status='canceled' THEN NULL ELSE o.order_date + INTERVAL 2 DAY END,
       CASE WHEN o.order_status='delivered' THEN o.order_date + INTERVAL (4 + MOD(o.order_id,12)) DAY ELSE NULL END,
       DATE(o.order_date + INTERVAL 10 DAY)
FROM orders o;

SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'categories', COUNT(*) FROM categories
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'payments', COUNT(*) FROM payments
UNION ALL SELECT 'shipments', COUNT(*) FROM shipments;
