-- Reusable analysis objects: views, procedure, and a data-quality trigger.
USE olist_resume_analytics;

CREATE OR REPLACE VIEW v_order_revenue AS
SELECT o.order_id, o.customer_id, o.order_date, o.order_status,
       COALESCE(SUM(i.quantity * i.unit_price - i.discount_amount),0) AS merchandise_revenue,
       COALESCE(SUM(i.quantity),0) AS units
FROM orders o LEFT JOIN order_items i ON i.order_id=o.order_id
GROUP BY o.order_id, o.customer_id, o.order_date, o.order_status;

CREATE OR REPLACE VIEW v_monthly_sales AS
SELECT DATE_FORMAT(order_date,'%Y-%m-01') AS sales_month,
       COUNT(*) AS delivered_orders,
       SUM(merchandise_revenue) AS gross_merchandise_revenue,
       SUM(units) AS units_sold
FROM v_order_revenue
WHERE order_status='delivered'
GROUP BY DATE_FORMAT(order_date,'%Y-%m-01');

DROP PROCEDURE IF EXISTS sp_sales_by_state;
DELIMITER $$
CREATE PROCEDURE sp_sales_by_state(IN p_start DATE, IN p_end DATE)
BEGIN
  SELECT c.state, COUNT(DISTINCT o.order_id) AS delivered_orders,
         ROUND(SUM(r.merchandise_revenue),2) AS revenue
  FROM customers c
  JOIN v_order_revenue r ON r.customer_id=c.customer_id
  JOIN orders o ON o.order_id=r.order_id
  WHERE o.order_status='delivered'
    AND o.order_date >= p_start
    AND o.order_date < DATE_ADD(p_end, INTERVAL 1 DAY)
  GROUP BY c.state
  ORDER BY revenue DESC;
END$$

DROP TRIGGER IF EXISTS trg_payment_amount_matches_items$$
CREATE TRIGGER trg_payment_amount_matches_items
BEFORE INSERT ON payments
FOR EACH ROW
BEGIN
  DECLARE expected_amount DECIMAL(12,2);
  SELECT COALESCE(SUM(quantity * unit_price - discount_amount),0)
    INTO expected_amount FROM order_items WHERE order_id=NEW.order_id;
  IF ABS(NEW.amount - expected_amount) > 0.01 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Payment amount must match the order item total';
  END IF;
END$$
DELIMITER ;
