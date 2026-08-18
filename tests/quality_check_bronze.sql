/*
===============================================================================
Quality Checks
===============================================================================
Script Purpose:
    This script performs various quality checks for data consistency, accuracy, 
    and standardization across the 'bronze' layer. It includes checks for:
    - Null or duplicate primary keys.
    - Unwanted spaces in string fields.
    - Data standardization and consistency.
    - Invalid date ranges and orders.
    - Data consistency between related fields.

Usage Notes:
    - Run these checks after data loading Bronze Layer.
    - Investigate and resolve any discrepancies found during the checks.
===============================================================================
*/


-- ====================================================================
-- Checking 'bronze.crm_cust_info'
-- ====================================================================
-- Check for NULLS or Duplicates in PK
-- Expectation: no results
SELECT
	cst_id,
	COUNT(*) AS PK_count
FROM bronze.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- Check for unwanted spaces in string columns
-- Expectation: no results
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

-- ====================================================================
-- Checking 'bronze.crm_prd_info'
-- ====================================================================
-- Check for NULLS or Duplicates in PK
-- Expectation: no results
SELECT
	prd_id,
	COUNT(*) AS PK_count
FROM bronze.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

-- Check for unwanted spaces in string columns
-- Expectation: no results
SELECT
    prd_nm
FROM bronze.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

-- Check prices for NULLs or negative numbers
-- Expectation: no results
SELECT
    prd_cost
FROM bronze.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;

-- Data Standardization & Consistency
-- Check unique product lines
SELECT DISTINCT
    prd_line
FROM bronze.crm_prd_info;

-- Check invalid order dates
SELECT
    *
FROM bronze.crm_prd_info
WHERE prd_end_dt < prd_start_dt;
