
-- 1. What are the top 5 brands by receipts scanned among users 21 and over?

-- Create a Common Table Expression (CTE) to filter users who are 21 years or older
WITH Eligible_Users AS (
    SELECT 
        ID,  
        DATEDIFF(YEAR, BIRTH_DATE, GETDATE()) AS AGE  -- Calculate user age
    FROM users
    WHERE DATEDIFF(YEAR, BIRTH_DATE, GETDATE()) >= 21  -- Filter users 21+
)

-- Retrieve the top 5 brands by the number of receipts scanned
SELECT 
    TOP 5 p.BRAND, 
    COUNT(*) AS TOTAL_RECEIPTS  -- Count occurrences of each brand in transactions
FROM Eligible_Users u
INNER JOIN transactions t ON u.ID = t.USER_ID  -- Join transactions with eligible users
INNER JOIN products p ON t.BARCODE = p.BARCODE  -- Join products to get brand details
WHERE p.BRAND IS NOT NULL  -- Exclude null brands
GROUP BY p.BRAND  -- Aggregate by brand
ORDER BY TOTAL_RECEIPTS DESC;  -- Sort in descending order to get top brands

-- Question 1 with window function: (faster)

WITH Eligible_Users AS (
    SELECT 
        ID,  
        DATEDIFF(YEAR, BIRTH_DATE, GETDATE()) AS AGE  -- Calculate user age
    FROM users
    WHERE DATEDIFF(YEAR, BIRTH_DATE, GETDATE()) >= 21  -- Filter users 21+
),
Brand_Receipts AS (
    -- Count occurrences of each brand using COUNT() OVER()
    SELECT 
        p.BRAND, 
        COUNT(*) AS TOTAL_RECEIPTS,
        RANK() OVER (ORDER BY COUNT(*) DESC) AS BRAND_RANK  -- Rank brands by total receipts
    FROM Eligible_Users u
    INNER JOIN transactions t ON u.ID = t.USER_ID  -- Join transactions with eligible users
    INNER JOIN products p ON t.BARCODE = p.BARCODE  -- Join products to get brand details
    WHERE p.BRAND IS NOT NULL  -- Exclude null brands
    GROUP BY p.BRAND  -- Aggregate by brand
)

SELECT BRAND, TOTAL_RECEIPTS
FROM Brand_Receipts
WHERE BRAND_RANK <= 5;  -- Retrieve only the top 5 brands



-- 2. What are the top 5 brands by sales among users that have had their account for at least six months?

-- Create a Common Table Expression (CTE) to filter users with accounts older than 6 months
WITH Active_Users AS (
    SELECT * 
    FROM users 
    WHERE CONVERT(DATE, CREATED_DATE) <= DATEADD(MONTH, -6, GETDATE())  -- Users with accounts older than 6 months
),
Brand_Sales AS (
    -- Calculate total sales for each brand and assign ranks
    SELECT 
        p.BRAND, 
        SUM(t.FINAL_SALE) AS TOTAL_SALES,
        DENSE_RANK() OVER (ORDER BY SUM(t.FINAL_SALE) DESC) AS BRAND_RANK  -- Rank brands by total sales
    FROM Active_Users AS u
    INNER JOIN transactions AS t ON t.USER_ID = u.ID  -- Join transactions with eligible users
    INNER JOIN products AS p ON p.BARCODE = t.BARCODE  -- Join products to get brand details
    WHERE p.BRAND IS NOT NULL  -- Exclude null brands
    GROUP BY p.BRAND  -- Aggregate sales by brand
)

-- Retrieve only the top 5 brands by total sales
SELECT BRAND, TOTAL_SALES
FROM Brand_Sales
WHERE BRAND_RANK <= 5
ORDER BY BRAND_RANK;



-- 3. What is the percentage of sales in the Health & Wellness category by generation?

-- CTE to categorize users into generations and filter transactions in the Health & Wellness category
WITH User_Generation AS (
    SELECT 
        p.CATEGORY_1,
        CASE 
            WHEN YEAR(u.BIRTH_DATE) BETWEEN 1928 AND 1945 THEN 'Silent Generation'
            WHEN YEAR(u.BIRTH_DATE) BETWEEN 1946 AND 1964 THEN 'Baby Boomer'
            WHEN YEAR(u.BIRTH_DATE) BETWEEN 1965 AND 1980 THEN 'Generation X'
            WHEN YEAR(u.BIRTH_DATE) BETWEEN 1981 AND 1996 THEN 'Millennial'
            WHEN YEAR(u.BIRTH_DATE) BETWEEN 1997 AND 2012 THEN 'Generation Z'
            WHEN YEAR(u.BIRTH_DATE) >= 2013 THEN 'Generation Alpha'
            ELSE 'Unknown'
        END AS GENERATION
    FROM users AS u
    INNER JOIN transactions AS t ON t.USER_ID = u.ID  -- Join transactions with users
    INNER JOIN products AS p ON p.BARCODE = t.BARCODE  -- Join products to get category details
    WHERE p.CATEGORY_1 = 'Health & Wellness'  -- Filter for Health & Wellness category
),

-- CTE to count transactions by generation
Generation_Sales AS (
    SELECT 
        GENERATION, 
        COUNT(*) AS SALES_COUNT
    FROM User_Generation
    GROUP BY GENERATION
)

-- Calculate percentage contribution of each generation to total sales in the Health & Wellness category
SELECT 
    GENERATION, 
    CAST(ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM User_Generation), 2) AS DECIMAL(5,2)) AS SALES_PERCENTAGE
FROM User_Generation
GROUP BY GENERATION;



----------------------------------------------------------------------------------------------------------------------------------------------------

---OPEN ENDED QUESTIONS---

-- 1. Who are Fetch’s power users?

--Power Users by Transaction Count

-- CTE to join users with their transaction data
WITH User_Transactions AS (
    SELECT * 
    FROM users AS u
    INNER JOIN transactions AS t ON t.USER_ID = u.ID  -- Join transactions with users
)

-- Fetch Power Users based on transaction count
SELECT 
    USER_ID, 
    COUNT(*) AS NUM_OF_TRANSACTIONS  -- Count number of transactions per user
FROM User_Transactions
GROUP BY USER_ID
ORDER BY NUM_OF_TRANSACTIONS DESC;  -- Sort by highest transaction count



--Power Users by Both Transaction Count & Spending

-- CTE to join users with their transaction data
WITH User_Transactions AS (
    SELECT * 
    FROM users AS u
    INNER JOIN transactions AS t ON t.USER_ID = u.ID  -- Join transactions with users
)

-- Fetch Power Users based on both total spending and transaction count
SELECT 
    USER_ID,  
    SUM(FINAL_SALE) AS TOTAL_SPENT,  -- Total amount spent by the user
    COUNT(*) AS TRANSACTION_COUNT  -- Total number of transactions by the user
FROM User_Transactions
GROUP BY USER_ID
ORDER BY TOTAL_SPENT DESC, TRANSACTION_COUNT DESC;  -- Sort by highest spending, then by transaction count





---2. Which is the leading brand in the Dips & Salsa category?


--BY SALES

-- CTE to filter transactions in the 'Dips & Salsa' category
WITH Dips_Salsa_Sales AS (
    SELECT 
        p.BRAND, 
        t.FINAL_SALE, 
        t.FINAL_QUANTITY, 
        p.CATEGORY_2 
    FROM products AS p
    INNER JOIN transactions AS t ON t.BARCODE = p.BARCODE  -- Join transactions with products
    WHERE p.CATEGORY_2 = 'Dips & Salsa'  -- Filter for Dips & Salsa category
)

-- Find the leading brand in the Dips & Salsa category by total sales
SELECT 
    BRAND, 
    SUM(FINAL_SALE) AS TOTAL_REVENUE  -- Sum of all sales for each brand
FROM Dips_Salsa_Sales
WHERE BRAND IS NOT NULL
GROUP BY BRAND
ORDER BY TOTAL_REVENUE DESC;  -- Sort in descending order to get the top brand


--BY FREQUENCY

-- CTE to filter transactions in the 'Dips & Salsa' category
WITH Dips_Salsa_Frequency AS (
    SELECT 
        p.BRAND, 
        t.FINAL_SALE, 
        t.FINAL_QUANTITY, 
        p.CATEGORY_2, 
        t.RECEIPT_ID 
    FROM products AS p
    INNER JOIN transactions AS t ON t.BARCODE = p.BARCODE  -- Join transactions with products
    WHERE p.CATEGORY_2 = 'Dips & Salsa'  -- Filter for Dips & Salsa category
)

-- Find the leading brand in the Dips & Salsa category by frequency of purchases
SELECT 
    BRAND, 
    COUNT(*) AS PURCHASE_COUNT  -- Count the number of transactions for each brand
FROM Dips_Salsa_Frequency
WHERE BRAND IS NOT NULL
GROUP BY BRAND
ORDER BY PURCHASE_COUNT DESC;  -- Sort in descending order to get the most frequently purchased brand


-----3. At what percent has Fetch grown year over year?


-- CTE to calculate the number of new users registered each year
WITH Yearly_User_Growth AS (
    SELECT 
        YEAR(CREATED_DATE) AS reSgistration_year,  -- Extract year from CREATED_DATE
        COUNT(ID) AS new_users  -- Count number of new users per year
    FROM users
    GROUP BY YEAR(CREATED_DATE)
)

-- Calculate Year-over-Year (YoY) growth percentage
SELECT 
    Y1.registration_year AS current_year, 
    Y1.new_users AS current_users,  -- New users in the current year
    Y2.new_users AS previous_users,  -- New users in the previous year
    CAST(ROUND((Y1.new_users - Y2.new_users) * 100.0 / Y2.new_users, 2) AS DECIMAL(5,2)) AS YoY_growth_percent
FROM Yearly_User_Growth Y1
LEFT JOIN Yearly_User_Growth Y2 
    ON Y1.registration_year = Y2.registration_year + 1  -- Join with previous year data
ORDER BY Y1.registration_year;