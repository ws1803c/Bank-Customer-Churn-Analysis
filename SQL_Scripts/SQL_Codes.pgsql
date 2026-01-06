-- ## IMPORT LOCAL DATASET
-- Create the empty table structure
CREATE TABLE bank_churn (
    RowNumber INT,
    CustomerId INT,
    Surname VARCHAR(100),
    CreditScore INT,
    Geography VARCHAR(50),
    Gender VARCHAR(20),
    Age INT,
    Tenure INT,
    Balance DECIMAL(15, 2),
    NumOfProducts INT,
    HasCrCard INT,
    IsActiveMember INT,
    EstimatedSalary DECIMAL(15, 2),
    Exited INT
);

-- Change the file path inside the quotes '' to match where you put your file
-- This is to upload the downloaded data onto the database
COPY bank_churn(RowNumber, CustomerId, Surname, CreditScore, Geography, Gender,
Age, Tenure, Balance, NumOfProducts, HasCrCard, IsActiveMember, EstimatedSalary, Exited)
FROM 'file_location'
DELIMITER ','
CSV HEADER;

-- ## DATA CHECK
-- Account for weird values
SELECT * FROM bank_churn WHERE age < 18;
-- Result showed found none.

-- Finance Check
SELECT * FROM bank_churn WHERE balance < 0;
-- Result showed found none.

-- ## ANALYSIS
-- Calculate Churn Rate by Income Group
SELECT
    CASE
        WHEN EstimatedSalary < 50000 THEN 'Low Income'
        WHEN EstimatedSalary BETWEEN 50000 AND 100000 THEN 'Middle Income'
        ELSE 'High Income'
    END AS income_group,
    COUNT(CustomerId) as total_customers,
    SUM(Exited) as churned_customers,
    ROUND(AVG(Exited)::numeric * 100, 2) as churn_rate_pct
FROM bank_churn
GROUP BY 1
ORDER BY churn_rate_pct DESC;
-- Results show the different groups have approximately 20% churn rate,
-- to note: High Income has double of the total customers than in Low or Medium Income
-- Income Group has little impact on churn rate based on simple grouping

-- Calculate Churn Rate by Age Group
WITH Query_Age_Group AS(
    SELECT
        *,
        CASE
            WHEN Age < 30 THEN 'Young'
            WHEN Age BETWEEN 30 AND 50 THEN 'Middle-Aged'
            ELSE 'Senior'
        END AS Age_Group
    FROM bank_churn
)
SELECT
    Age_Group, 
    COUNT(*) as Total_Customers,
    SUM(Exited) as Churned_Customers,
    ROUND(AVG(Exited)::numeric * 100, 2) as Churn_Rate
FROM Query_Age_Group
GROUP BY Age_Group
ORDER BY 
    CASE 
        WHEN Age_Group = 'Young' THEN 1
        WHEN Age_Group = 'Middle-Aged' THEN 2
        WHEN Age_Group = 'Senior' THEN 3
    END;
-- Senior (Age > 50) shows 44.65% churn rate among 1261 senior customers
-- Further objective to identify reason of senior high churn rate

-- Analyse possible reasons for high churn rate in Senior customers
WITH Unioned_Result AS(
    SELECT
        CASE WHEN Age > 50 THEN 'Senior' ELSE 'Non-Senior' END AS Age_Category,
        numofproducts,
        COUNT(*) as Total_Customers,
        SUM(Exited) as Churned_Customers,
        ROUND(AVG(Exited)::numeric * 100, 2) as Churn_Rate
    FROM bank_churn
    GROUP BY 1, 2
    UNION ALL
    SELECT
        'OVERALL TOTAL' as Age_Category,
        numofproducts,
        COUNT(*) as Total_Customers,
        SUM(Exited) as Churned_Customers,
        ROUND(AVG(Exited)::numeric * 100, 2) as Churn_Rate
    FROM bank_churn
    GROUP BY 2
)
SELECT * FROM Unioned_Result
ORDER BY
    CASE
        WHEN Age_Category = 'Non-Senior' THEN 1
        WHEN Age_Category = 'Senior' THEN 2
        ELSE 3 
    END, numofproducts;
-- Results showed senior customers with 3 or 4 number of products have
-- exceptionlly high churn rate, while 1 number of product also show high
-- churn rate. This does not bring large insight as only small comparative
-- proportion of customers for 3 and 4 number of products.

-- Determine effect of geography on churn rate
SELECT
    CASE WHEN Age > 50 THEN 'Senior' ELSE 'Non-Senior' END AS Age_Category,
    geography,
    COUNT(*) as Total_Customers,
    SUM(Exited) as Churned_Customers,
    ROUND(AVG(Exited)::numeric * 100, 2) as Churn_Rate,
    1 AS sort_priority -- Helps keep the total at the bottom
FROM bank_churn
GROUP BY 1, 2
UNION ALL
SELECT
    'OVERALL TOTAL' as Age_Category,
    geography,
    COUNT(*) as Total_Customers,
    SUM(Exited) as Churned_Customers,
    ROUND(AVG(Exited)::numeric * 100, 2) as Churn_Rate,
    2 AS sort_priority
FROM bank_churn
GROUP BY 2
ORDER BY sort_priority, Age_Category, geography;
-- Highest churn rate in Germany

-- Acquire ranking for highest churn rate by breakdown of geography and numofproducts
WITH Churn_Ranking AS (
    SELECT 
        Geography,
        NumOfProducts,
        COUNT(*) as Total,
        ROUND(AVG(Exited) * 100, 2) as Churn_Rate,
        RANK() OVER(PARTITION BY Geography ORDER BY AVG(Exited) DESC) as Risk_Rank
    FROM bank_churn
    GROUP BY Geography, NumOfProducts
)
SELECT * FROM Churn_Ranking WHERE Risk_Rank <= 3 ORDER BY risk_rank, churn_rate DESC;


-- ## FINAL DATASET TO USE
SELECT
    *,
    CASE
        WHEN EstimatedSalary < 50000 THEN 'Low Income'
        WHEN EstimatedSalary BETWEEN 50000 AND 100000 THEN 'Middle Income'
        ELSE 'High Income'
    END AS Income_Group,
    CASE
        WHEN Age < 30 THEN 'Young'
        WHEN Age BETWEEN 30 AND 50 THEN 'Middle-Aged'
        ELSE 'Senior'
    END AS Age_Group
FROM bank_churn;
