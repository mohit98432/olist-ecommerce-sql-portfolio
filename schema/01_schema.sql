-- Olist marketplace analytics portfolio | MySQL 8.0
-- Run in MySQL Workbench. This creates a dedicated schema and does not alter other databases.
CREATE DATABASE IF NOT EXISTS olist_resume_analytics
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE olist_resume_analytics;

CREATE TABLE IF NOT EXISTS customers (
  customer_id INT UNSIGNED PRIMARY KEY,
  customer_unique_id CHAR(32) NOT NULL UNIQUE,
  city VARCHAR(100) NOT NULL,
  state CHAR(2) NOT NULL,
  created_at DATETIME NOT NULL,
  CONSTRAINT chk_customer_state CHECK (CHAR_LENGTH(state) = 2)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS categories (
  category_id SMALLINT UNSIGNED PRIMARY KEY,
  category_name VARCHAR(80) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS products (
  product_id INT UNSIGNED PRIMARY KEY,
  category_id SMALLINT UNSIGNED NOT NULL,
  product_name VARCHAR(120) NOT NULL,
  list_price DECIMAL(10,2) NOT NULL,
  weight_grams INT UNSIGNED NOT NULL,
  CONSTRAINT chk_product_price CHECK (list_price > 0),
  CONSTRAINT fk_product_category FOREIGN KEY (category_id)
    REFERENCES categories(category_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS orders (
  order_id INT UNSIGNED PRIMARY KEY,
  customer_id INT UNSIGNED NOT NULL,
  order_date DATETIME NOT NULL,
  order_status ENUM('delivered','shipped','processing','canceled') NOT NULL,
  CONSTRAINT fk_order_customer FOREIGN KEY (customer_id)
    REFERENCES customers(customer_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS order_items (
  order_id INT UNSIGNED NOT NULL,
  item_number TINYINT UNSIGNED NOT NULL,
  product_id INT UNSIGNED NOT NULL,
  quantity TINYINT UNSIGNED NOT NULL,
  unit_price DECIMAL(10,2) NOT NULL,
  discount_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
  PRIMARY KEY (order_id, item_number),
  CONSTRAINT chk_item_quantity CHECK (quantity BETWEEN 1 AND 10),
  CONSTRAINT chk_item_price CHECK (unit_price > 0),
  CONSTRAINT chk_item_discount CHECK (discount_amount >= 0 AND discount_amount < unit_price * quantity),
  CONSTRAINT fk_item_order FOREIGN KEY (order_id)
    REFERENCES orders(order_id) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_item_product FOREIGN KEY (product_id)
    REFERENCES products(product_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS payments (
  payment_id INT UNSIGNED PRIMARY KEY,
  order_id INT UNSIGNED NOT NULL UNIQUE,
  payment_method ENUM('credit_card','boleto','debit_card','voucher') NOT NULL,
  payment_status ENUM('paid','refunded','pending') NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  paid_at DATETIME NULL,
  CONSTRAINT chk_payment_amount CHECK (amount >= 0),
  CONSTRAINT fk_payment_order FOREIGN KEY (order_id)
    REFERENCES orders(order_id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS shipments (
  shipment_id INT UNSIGNED PRIMARY KEY,
  order_id INT UNSIGNED NOT NULL UNIQUE,
  shipped_at DATETIME NULL,
  delivered_at DATETIME NULL,
  estimated_delivery DATE NOT NULL,
  CONSTRAINT chk_shipment_dates CHECK (delivered_at IS NULL OR shipped_at IS NULL OR delivered_at >= shipped_at),
  CONSTRAINT fk_shipment_order FOREIGN KEY (order_id)
    REFERENCES orders(order_id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- Supporting indexes are added separately in 03_indexes_and_plans.sql.
