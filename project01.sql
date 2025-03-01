use ecommerce;


-- Modify the column names of the orders table
ALTER TABLE orders RENAME COLUMN `Order ID`  TO order_id,
				   RENAME COLUMN `Order Date` TO order_date,
                   RENAME COLUMN `CustomerName` TO customer_name,
                   RENAME COLUMN `State` TO state,
                   RENAME COLUMN `City` TO city;

-- Modify the column names of the orders table
ALTER TABLE order_details RENAME COLUMN `Order ID` TO order_id,
						  RENAME COLUMN `Amount` TO amount,
                          RENAME COLUMN `Profit` TO profit,
                          RENAME COLUMN `Quantity` TO quantity,
                          RENAME COLUMN `Category` TO category,
                          RENAME COLUMN `Sub-Category` TO sub_category;
                          
-- Modify the column names of the sales_target table
ALTER TABLE sales_target RENAME COLUMN `Month of Order Date` TO month_of_order,
						 RENAME COLUMN `Category` TO category,
						RENAME COLUMN `Target` TO target;

-- Delete the empty row in the orders table
DELETE 
FROM orders
WHERE order_date = '';

-- Stndarize the date format
UPDATE orders
			 SET order_date = STR_TO_DATE(order_date, '%d-%m-%Y');
             
-- Modify the column data types for the orders table
ALTER TABLE orders MODIFY COLUMN order_id VARCHAR(25),
				   MODIFY COLUMN order_date DATE,
                   MODIFY COLUMN customer_name VARCHAR(25),
                   MODIFY COLUMN state VARCHAR(25),
                   MODIFY COLUMN city VARCHAR(25);

-- Modify the column data types for the order_details table
ALTER TABLE order_details MODIFY COLUMN order_id VARCHAR(25),
						  MODIFY COLUMN category VARCHAR(25),
                          MODIFY COLUMN sub_category VARCHAR(25);
                          
-- Modify the column data types for the sales_target table
ALTER TABLE sales_target MODIFY COLUMN month_of_order VARCHAR(25),
						  MODIFY COLUMN category VARCHAR(25);
                          
-- Set the primary keys for all tables
ALTER TABLE orders ADD PRIMARY KEY (order_id);
ALTER TABLE sales_target ADD PRIMARY KEY (month_of_order, category);
ALTER TABLE sales_target ADD COLUMN id INT AUTO_INCREMENT PRIMARY KEY;

-- Find the number of orders, customers, cities and states
SELECT COUNT(order_id) AS number_of_orders,
	   COUNT(distinct customer_name) AS number_of_customers,
       COUNT(distinct city) AS number_of_cities,
       COUNT(distinct state) AS number_of_states
FROM orders;

-- Find the top-5 new customers for the year 2019
CREATE VIEW combined_orders AS
SELECT o.order_id, o.order_date, o.customer_name, o.state, o.city, d.amount, d.profit, d.quantity, d.category, d.sub_category   
FROM orders o INNER JOIN order_details d ON o.order_id = d.order_id;

WITH customer_spend AS (
		SELECT customer_name, YEAR(order_date) as `year`, state, city, SUM(amount) AS spend_amount,
			   DENSE_RANK() OVER(ORDER BY SUM(amount) DESC) as `rank`
		FROM combined_orders
		WHERE YEAR(order_date) = 2019
		GROUP BY customer_name, `year`, state, city
        )
SELECT customer_name, state, city, spend_amount
FROM customer_spend
WHERE `rank` <= 5;

-- Find the top-10 profitable states & cities and the number of products sold and the number of customers in these top 10 profitable states & cities
     -- top-10 states
	WITH state_profit AS (
	SELECT state, SUM(profit) as profit,
    DENSE_RANK() OVER(ORDER BY SUM(profit) DESC) as `rank`
    FROM combined_orders
    GROUP BY state
	)
	SELECT state, profit FROM state_profit
	WHERE `rank` <= 10
	ORDER BY profit DESC;
    
    -- top_10 cities
    WITH city_profit AS (
	SELECT city, SUM(profit) as profit,
    DENSE_RANK() OVER(ORDER BY SUM(profit) DESC) as `rank`
    FROM combined_orders
    GROUP BY city
	)
	SELECT city, profit FROM city_profit
	WHERE `rank` <= 10
	ORDER BY profit DESC;

-- Information about first order in each state
WITH orders_rank AS (
	SELECT state, order_id, order_date, customer_name, city, amount, profit, category, sub_category, quantity,
	   DENSE_RANK() OVER(PARTITION BY state ORDER BY order_date) as order_rank
	FROM combined_orders
)
SELECT *
FROM orders_rank
WHERE order_rank = 1;

-- Determine the number of orders and sales for different days of the week in form of a histogram.
SELECT DAYNAME(order_date) as weekday, LPAD('*', COUNT(DISTINCT order_id), '*') AS number_of_orders, SUM(amount) as total_sales
FROM combined_orders
GROUP BY weekday
ORDER BY number_of_orders DESC, total_sales DESC;

-- Monthly profit and quantity sold
SELECT MONTH(order_date) AS `month`,  SUM(profit) AS profit, SUM(quantity) AS quantity
FROM combined_orders
GROUP BY `month`
ORDER BY `month`;

-- Determine the number of times that salespeople hit or failed to hit the sales target for each category.
WITH m AS (
		SELECT category,
			   CONCAT(SUBSTRING(MONTHNAME(order_date), 1, 3), '-', YEAR(order_date) - 2000) AS month,
			   SUM(amount) AS total_amount
		FROM combined_orders
        GROUP BY month, category
), 
	j AS (
		SELECT m.month, m.category, m.total_amount, t.target, total_amount - target as diff
        FROM m INNER JOIN sales_target t ON m.category = t.category AND m.month = t.month_of_order
)

select category, COUNT(CASE WHEN diff >= 0 THEN 1 END) AS hits,
				 COUNT(CASE WHEN diff < 0 THEN 1 END) AS fails
FROM j
GROUP BY category;

-- Find the total sales, total profit, and total quantity sold for each category and sub-category. Return the maximum cost and maximum price for each sub-category too.
SELECT category, sub_category, SUM(profit) AS total_profit, SUM(quantity) AS total_quantity, SUM(amount) AS total_sales,
       MAX(ROUND((amount / quantity), 2)) AS max_price_unit, MAX(ROUND(((amount - profit) / quantity), 2)) AS max_cost_unit
FROM combined_orders 
GROUP BY category, sub_category
ORDER BY total_profit DESC, total_sales DESC, total_quantity DESC;

-- Get the cumulative profit along months
WITH mp AS (
    SELECT CONCAT(SUBSTRING(MONTHNAME(order_date), 1, 3), '-', SUBSTRING(YEAR(order_date), 3, 2)) AS month,
           SUM(profit) AS total_profit
    FROM combined_orders
    GROUP BY month
    ORDER BY MIN(order_date)
)
SELECT *, 
       CASE 
           WHEN LAG(total_profit) OVER() + total_profit IS NULL THEN total_profit
           ELSE LAG(total_profit) OVER() + total_profit 
       END AS previous_profit
FROM mp;

-- Average spend amount per client
SELECT ROUND((SUM(amount) / COUNT(DISTINCT customer_name)), 2) as average_amount_per_client
FROM combined_orders;

-- Percentage of positive profit per city
SELECT state, city, ROUND((SUM(profit) / (SELECT SUM(profit) FROM combined_orders)) * 100, 2) as profit_percentage
FROM combined_orders
WHERE profit >= 0
GROUP BY state, city
ORDER BY profit_percentage DESC;

-- Percentage of negative profit (loss) per city
SELECT state, city, ROUND((ABS(SUM(profit)) / (SELECT SUM(profit) FROM combined_orders)) * 100, 2) as profit_percentage
FROM combined_orders
WHERE profit < 0
GROUP BY state, city
ORDER BY profit_percentage DESC;

-- average time (in days) between two orders
WITH od AS (
    SELECT customer_name, order_date,
        DATEDIFF(order_date, LAG(order_date) OVER(PARTITION BY customer_name ORDER BY order_date)) AS diff
    FROM orders
)
SELECT ROUND(AVG(diff)) AS average_days_between_two_orders FROM od;
 
-- Products often sold together
WITH p AS (
    SELECT c1.order_id, LEAST(c1.sub_category, c2.sub_category) AS sub_category_1, 
						GREATEST(c1.sub_category, c2.sub_category) AS sub_category_2
    FROM combined_orders c1 
    INNER JOIN combined_orders c2 
    ON c1.order_id = c2.order_id 
    AND c1.sub_category <> c2.sub_category 
)

SELECT p.sub_category_1, p.sub_category_2, ROUND(COUNT(*) / 2) AS num_occurences
FROM p 
GROUP BY p.sub_category_1, p.sub_category_2
ORDER BY num_occurences DESC;

-- Segment customers according to their expenses
SELECT customer_name, SUM(amount) as total_expenses,
	   CASE WHEN SUM(amount) > 4000 THEN 'High'
			WHEN SUM(amount) < 4000 AND SUM(amount) > 2000 THEN 'Medium'
            ELSE 'Low'
            END AS expenses
FROM combined_orders
GROUP BY customer_name
ORDER BY total_expenses DESC;

-- Total orders per season
SELECT CASE WHEN MONTH(order_date) IN (12, 1, 2) THEN 'Winter'
			WHEN MONTH(order_date) IN (3, 4, 5) THEN 'Spring'
			WHEN MONTH(order_date) IN (6, 7, 8) THEN 'Summer'
			ELSE 'Autumn'
	  END AS season,
      COUNT(DISTINCT order_id) as total_orders
FROM combined_orders
GROUP BY season;

-- Monthly growth rate for each sub category of products
SELECT category, sub_category, CONCAT(SUBSTRING(MONTHNAME(order_date), 1, 3), '-', SUBSTRING(YEAR(order_date), 3, 2)) as month, SUM(quantity) as total_sales,
	   CONCAT(ROUND((SUM(quantity) - (LAG(SUM(quantity)) OVER(PARTITION BY category, sub_category ORDER BY MIN(order_date)))) * 100 / (LAG(SUM(quantity)) OVER(PARTITION BY category, sub_category ORDER BY MIN(order_date)))), '%') as growth_rate
FROM combined_orders 
GROUP BY month, category, sub_category;

-- Customers who return after an initial order
SELECT customer_name, COUNT(DISTINCT order_id) as number_orders
FROM combined_orders
GROUP BY customer_name
HAVING number_orders > 1;



