CREATE DATABASE sales_analysis;
USE sales_analysis;

CREATE TABLE customers (
    customer_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100),
    signup_date DATE,
    region ENUM('North', 'South', 'East', 'West')
);

CREATE TABLE products (
    product_id INT PRIMARY KEY AUTO_INCREMENT,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50),
    unit_price DECIMAL(10,2) NOT NULL
);

CREATE TABLE orders (
    order_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT,
    order_date DATE NOT NULL,
    status ENUM('Pending', 'Shipped', 'Delivered', 'Cancelled'),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE order_details (
    order_detail_id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT,
    product_id INT,
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    discount DECIMAL(4,2) DEFAULT 0.00,
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE returns (
    return_id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT,
    return_date DATE,
    reason VARCHAR(255),
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

desc returns;
desc orders;
desc order_details;
desc customers;
desc products;



INSERT INTO customers (name, email, signup_date, region) VALUES
('John Smith', 'john@example.com', '2023-01-15', 'North'),
('Emma Davis', 'emma@example.com', '2023-02-20', 'South'),
('Michael Brown', 'michael@example.com', '2023-03-10', 'East'),
('Sarah Johnson', 'sarah@example.com', '2023-01-05', 'West'),
('David Wilson', 'david@example.com', '2023-04-12', 'North');

INSERT INTO products (product_name, category, unit_price) VALUES
('Laptop Pro', 'Electronics', 1200.00),
('Wireless Mouse', 'Accessories', 25.99),
('Mechanical Keyboard', 'Accessories', 89.99),
('4K Monitor', 'Electronics', 450.00),
('Webcam HD', 'Accessories', 59.99);

INSERT INTO orders (customer_id, order_date, status) VALUES
(1, '2023-05-10', 'Delivered'),
(2, '2023-05-12', 'Shipped'),
(3, '2023-05-15', 'Pending'),
(1, '2023-05-18', 'Delivered'),
(4, '2023-05-20', 'Cancelled');

INSERT INTO order_details (order_id, product_id, quantity, unit_price, discount) VALUES
(1, 1, 1, 1200.00, 0.05),
(1, 2, 2, 25.99, 0.00),
(2, 3, 1, 89.99, 0.10),
(3, 4, 1, 450.00, 0.15),
(4, 5, 3, 59.99, 0.00);

INSERT INTO returns (order_id, return_date, reason) VALUES
(1, '2023-05-25', 'Defective product');

select * from returns;
select * from order_details;
select * from orders;
select * from products;
select * from customers;



-- Monthly sales revenue and average order value




SELECT
    DATE_FORMAT(o.order_date, '%Y-%m') AS month,
    SUM(od.quantity * od.unit_price * (1 - od.discount)) AS total_revenue,
    AVG(od.quantity * od.unit_price * (1 - od.discount)) AS avg_order_value,
    COUNT(DISTINCT o.order_id) AS orders_count
FROM orders o
JOIN order_details od ON o.order_id = od.order_id
WHERE o.status != 'Cancelled'
GROUP BY month
ORDER BY month;





-- RFM (Recency, Frequency, Monetary) Analysis




WITH customer_rfm AS (
    SELECT
        c.customer_id,
        c.name,
        DATEDIFF(CURDATE(), MAX(o.order_date)) AS recency,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(od.quantity * od.unit_price * (1 - od.discount)) AS monetary
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    LEFT JOIN order_details od ON o.order_id = od.order_id
    WHERE o.status = 'Delivered'
    GROUP BY c.customer_id, c.name
)
SELECT
    customer_id,
    name,
    recency,
    frequency,
    monetary,
    NTILE(4) OVER (ORDER BY recency DESC) AS r_score,
    NTILE(4) OVER (ORDER BY frequency) AS f_score,
    NTILE(4) OVER (ORDER BY monetary) AS m_score,
    CONCAT(
        NTILE(4) OVER (ORDER BY recency DESC),
        NTILE(4) OVER (ORDER BY frequency),
        NTILE(4) OVER (ORDER BY monetary)
    ) AS rfm_cell
FROM customer_rfm;




-- Product performance with return rates





SELECT
    p.product_id,
    p.product_name,
    p.category,
    SUM(od.quantity) AS total_units_sold,
    SUM(od.quantity * od.unit_price * (1 - od.discount)) AS total_revenue,
    COUNT(DISTINCT r.return_id) AS return_count,
    ROUND(COUNT(DISTINCT r.return_id) / COUNT(DISTINCT od.order_id) * 100, 2) AS return_rate
FROM products p
JOIN order_details od ON p.product_id = od.product_id
JOIN orders o ON od.order_id = o.order_id
LEFT JOIN returns r ON o.order_id = r.order_id
WHERE o.status = 'Delivered'
GROUP BY p.product_id, p.product_name, p.category
ORDER BY total_revenue DESC;





-- Regional sales performance with YoY growth




SELECT
    c.region,
    YEAR(o.order_date) AS year,
    SUM(od.quantity * od.unit_price * (1 - od.discount)) AS total_sales,
    LAG(SUM(od.quantity * od.unit_price * (1 - od.discount))) 
        OVER (PARTITION BY c.region ORDER BY YEAR(o.order_date)) AS prev_year_sales,
    ROUND(
        (SUM(od.quantity * od.unit_price * (1 - od.discount)) - 
        LAG(SUM(od.quantity * od.unit_price * (1 - od.discount))) 
            OVER (PARTITION BY c.region ORDER BY YEAR(o.order_date))
        ) / 
        LAG(SUM(od.quantity * od.unit_price * (1 - od.discount))) 
            OVER (PARTITION BY c.region ORDER BY YEAR(o.order_date)) * 100,
    2) AS yoy_growth
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_details od ON o.order_id = od.order_id
WHERE o.status = 'Delivered'
GROUP BY c.region, year
ORDER BY c.region, year;





-- Cohort-based retention analysis




WITH cohort AS (
    SELECT
        customer_id,
        DATE_FORMAT(MIN(order_date), '%Y-%m') AS cohort_month
    FROM orders
    WHERE status = 'Delivered'
    GROUP BY customer_id
),
activity AS (
    SELECT
        o.customer_id,
        c.cohort_month,
        DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,
        TIMESTAMPDIFF(MONTH, 
            STR_TO_DATE(CONCAT(c.cohort_month,'-01'), '%Y-%m-%d'),
            STR_TO_DATE(CONCAT(DATE_FORMAT(o.order_date, '%Y-%m'),'-01'), '%Y-%m-%d')
        ) AS month_number
    FROM orders o
    JOIN cohort c ON o.customer_id = c.customer_id
    WHERE o.status = 'Delivered'
)
SELECT
    cohort_month,
    COUNT(DISTINCT CASE WHEN month_number = 0 THEN customer_id END) AS month_0,
    ROUND(COUNT(DISTINCT CASE WHEN month_number = 1 THEN customer_id END) / 
          COUNT(DISTINCT CASE WHEN month_number = 0 THEN customer_id END) * 100, 1) AS retention_month_1,
    ROUND(COUNT(DISTINCT CASE WHEN month_number = 3 THEN customer_id END) / 
          COUNT(DISTINCT CASE WHEN month_number = 0 THEN customer_id END) * 100, 1) AS retention_month_3,
    ROUND(COUNT(DISTINCT CASE WHEN month_number = 6 THEN customer_id END) / 
          COUNT(DISTINCT CASE WHEN month_number = 0 THEN customer_id END) * 100, 1) AS retention_month_6
FROM activity
GROUP BY cohort_month
ORDER BY cohort_month;







