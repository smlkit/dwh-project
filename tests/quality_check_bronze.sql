-- Check for NULLS or Duplicates in PK
-- Expectation: no results
SELECT
	cst_id,
	COUNT(*) AS PK_count
FROM bronze.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- Check for unwanted spaces in string columns
-- Expectation: no Results
SELECT 
    cst_firstname 
FROM bronze.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);

-- Data Standardization & Consistency
-- Check unique genders & marital status options
SELECT DISTINCT 
    cst_gndr
FROM bronze.crm_cust_info;

SELECT DISTINCT 
    cst_marital_status  
FROM bronze.crm_cust_info;
