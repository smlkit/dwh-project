/*
===============================================================================
Quality Checks
===============================================================================
Script Purpose:
    This script performs various quality checks for data consistency, accuracy, 
    and standardization across the 'silver' layer. It includes checks for:
    - Null or duplicate primary keys.
    - Unwanted spaces in string fields.
    - Data standardization and consistency.
    - Invalid date ranges and orders.
    - Data consistency between related fields.

Usage Notes:
    - Run these checks after data loading Silver Layer.
    - Investigate and resolve any discrepancies found during the checks.
===============================================================================
*/


-- ====================================================================
-- Checking 'silver.crm_cust_info'
-- ====================================================================
SELECT * FROM silver.crm_cust_info;
-- Check for NULLS or Duplicates in PK
-- Expectation: no results
SELECT
	cst_id,
	COUNT(*) AS PK_count
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- Check for unwanted spaces in string columns
-- Expectation: no results
SELECT 
    cst_firstname 
FROM silver.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);

-- Data Standardization & Consistency
-- Check unique genders & marital status options
SELECT DISTINCT 
    cst_gndr
FROM silver.crm_cust_info;

SELECT DISTINCT 
    cst_marital_status  
FROM silver.crm_cust_info;

-- ====================================================================
-- Checking 'silver.crm_prd_info'
-- ====================================================================
SELECT * FROM silver.crm_prd_info;
-- Check for NULLS or Duplicates in PK
-- Expectation: no results
SELECT
	prd_id,
	COUNT(*) AS PK_count
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

-- Check for unwanted spaces in string columns
-- Expectation: no results
SELECT
    prd_nm
FROM silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

-- Check prices for NULLs or negative numbers
-- Expectation: no results
SELECT
    prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;

-- Data Standardization & Consistency
-- Check unique product lines
SELECT DISTINCT
    prd_line
FROM silver.crm_prd_info;

-- Check invalid order dates
SELECT
    *
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt;

-- ====================================================================
-- Checking 'silver.crm_sales_details'
-- ====================================================================
SELECT * FROM silver.crm_sales_details;
-- Check for invalid dates
-- Expectation: no invalid dates
-- Check correct date order
SELECT
    *
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt
    OR sls_order_dt > sls_due_dt;

-- Check that:
-- sales = quantity * price & 
-- sls_price, sls_quantity, sls_sales >= 0 & NOT NULL
SELECT
    sls_price,
    sls_quantity,
    sls_sales
FROM silver.crm_sales_details
WHERE sls_price * sls_quantity != sls_sales
    OR sls_price IS NULL OR sls_quantity IS NULL OR sls_sales IS NULL
    OR sls_price <= 0 OR sls_quantity <= 0 OR sls_sales <= 0;

-- ====================================================================
-- Checking 'silver.erp_cust_az12'
-- ====================================================================
SELECT * FROM silver.erp_cust_az12;
-- Ckeck if any customers have birthday in future
-- Expectation: no results
SELECT
    bdate
FROM silver.erp_cust_az12
WHERE bdate > GETDATE();

-- Check all possible values in gender
-- Expectation: male, female, n/a
SELECT DISTINCT
    gen
FROM silver.erp_cust_az12;

-- ====================================================================
-- Checking 'silver.erp_loc_a101'
-- ====================================================================
SELECT * FROM silver.erp_loc_a101;
-- Check that all cid from erp_loc_a101 are usable in crm_cust_info
-- Expectation: no results
SELECT
    cid
FROM silver.erp_loc_a101
WHERE cid NOT IN (SELECT cst_key FROM silver.crm_cust_info);

-- Check all possible values in country
-- Expectation: full country names, n/a
SELECT DISTINCT
    cntry
FROM silver.erp_loc_a101;

-- ====================================================================
-- Checking 'silver.erp_px_cat_g1v2'
-- ====================================================================
SELECT * FROM silver.erp_px_cat_g1v2;
-- Check unwanted spaces in category & subcategoty name
-- Expectation: no results
SELECT
    *
FROM silver.erp_px_cat_g1v2
WHERE TRIM(cat) != cat;

SELECT
    *
FROM silver.erp_px_cat_g1v2
WHERE TRIM(subcat) != subcat;

-- Check all possible values in maintenance
-- Expectation: yes, no
SELECT DISTINCT
    maintenance
FROM silver.erp_px_cat_g1v2;

SELECT DISTINCT
    cat
FROM silver.erp_px_cat_g1v2;

SELECT DISTINCT
    subcat
FROM silver.erp_px_cat_g1v2;
