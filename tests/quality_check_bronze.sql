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
SELECT * FROM bronze.crm_cust_info;
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
    cst_gndr AS old_cst_gndr,
    CASE WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
		 WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
		 ELSE 'n/a'
		 END AS cst_gndr
FROM bronze.crm_cust_info;

SELECT DISTINCT 
    cst_marital_status AS old_cst_marital_status,
    CASE WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
		 WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
		 ELSE 'n/a'
	END AS cst_marital_status
FROM bronze.crm_cust_info;

-- ====================================================================
-- Checking 'bronze.crm_prd_info'
-- ====================================================================
SELECT * FROM bronze.crm_prd_info;
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
    prd_line AS old_prd_line,
    CASE UPPER(TRIM(prd_line))
		 WHEN 'M' THEN 'Mountain'
		 WHEN 'R' THEN 'Road'
		 WHEN 'S' THEN 'Other sales'
		 WHEN 'T' THEN 'Touring'
		 ELSE 'n/a'
	END AS prd_line
FROM bronze.crm_prd_info;

-- Check invalid order dates
SELECT
    *
FROM bronze.crm_prd_info
WHERE prd_end_dt < prd_start_dt;

-- ====================================================================
-- Checking 'bronze.crm_sales_details'
-- ====================================================================
SELECT * FROM bronze.crm_sales_details;
-- Check for invalid dates
-- Expectation: no invalid dates
-- sls_order_dt
SELECT
    NULLIF(sls_order_dt, 0) AS sls_order_dt
FROM bronze.crm_sales_details
WHERE sls_order_dt <= 0
    OR LEN(sls_order_dt) != 8
    OR sls_order_dt > 20500101
    OR sls_order_dt < 19000101;
-- sls_order_dt
SELECT
    NULLIF(sls_ship_dt, 0) AS sls_ship_dt
FROM bronze.crm_sales_details
WHERE sls_ship_dt <= 0
    OR LEN(sls_ship_dt) != 8
    OR sls_ship_dt > 20500101
    OR sls_ship_dt < 19000101;
-- sls_due_dt
SELECT
    NULLIF(sls_due_dt, 0) AS sls_due_dt
FROM bronze.crm_sales_details
WHERE sls_due_dt <= 0
    OR LEN(sls_due_dt) != 8
    OR sls_due_dt > 20500101
    OR sls_due_dt < 19000101;

-- Check correct date order
SELECT
    *
FROM bronze.crm_sales_details
WHERE sls_order_dt > sls_ship_dt
    OR sls_order_dt > sls_due_dt;

-- Check that:
-- sales = quantity * price & 
-- sls_price, sls_quantity, sls_sales >= 0 & NOT NULL
SELECT
    sls_price,
    sls_quantity,
    sls_sales
FROM bronze.crm_sales_details
WHERE sls_price * sls_quantity != sls_sales
    OR sls_price IS NULL OR sls_quantity IS NULL OR sls_sales IS NULL
    OR sls_price <= 0 OR sls_quantity <= 0 OR sls_sales <= 0;

-- ====================================================================
-- Checking 'bronze.erp_cust_az12'
-- ====================================================================
SELECT * FROM bronze.erp_cust_az12;
-- Ckeck if any customers have birthday in future
-- Expectation: no results
SELECT
    bdate
FROM bronze.erp_cust_az12
WHERE bdate > GETDATE();

-- Check that all cid from erp_cust_az12 are usable in crm_cust_info
-- Expectation: no results
SELECT
    CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
        ELSE cid
    END AS cid,
    bdate,
    gen
FROM bronze.erp_cust_az12
WHERE
    (CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
    ELSE cid END)
    NOT IN (SELECT DISTINCT cst_key FROM silver.crm_cust_info);

-- Check all possible values in gender
-- Expectation: male, female, n/a
SELECT DISTINCT
    gen AS old_gen,
    CASE WHEN UPPER(TRIM(gen)) IN ('M', 'Male') THEN 'Male'
		WHEN UPPER(TRIM(gen)) IN ('F', 'Female') THEN 'Female'
		ELSE 'n/a'
    END AS gen
FROM bronze.erp_cust_az12;

-- ====================================================================
-- Checking 'bronze.erp_loc_a101'
-- ====================================================================
SELECT * FROM bronze.erp_loc_a101;
-- Check that all cid from erp_loc_a101 are usable in crm_cust_info
-- Expectation: no results
SELECT
    cid
FROM bronze.erp_loc_a101
WHERE cid NOT IN (SELECT cst_key FROM silver.crm_cust_info);

-- Check all possible values in country
-- Expectation: full country names, n/a
SELECT DISTINCT
    cntry AS old_cntry,
    CASE WHEN TRIM(cntry) IN ('DE', 'Germany') THEN 'Germany'
		WHEN TRIM(cntry) IN ('US', 'USA', 'United States') THEN 'United States'
		WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
		ELSE TRIM(cntry)
	END AS cntry
FROM bronze.erp_loc_a101
ORDER BY cntry;

-- ====================================================================
-- Checking 'bronze.erp_px_cat_g1v2'
-- ====================================================================
SELECT * FROM bronze.erp_px_cat_g1v2;

-- Check unwanted spaces in category & subcategoty name
-- Expectation: no results
SELECT
    *
FROM bronze.erp_px_cat_g1v2
WHERE TRIM(cat) != cat;

SELECT
    *
FROM bronze.erp_px_cat_g1v2
WHERE TRIM(subcat) != subcat;

-- Check all possible values in maintenance
-- Expectation: yes, no
SELECT DISTINCT
    maintenance
FROM bronze.erp_px_cat_g1v2;

SELECT DISTINCT
    cat
FROM bronze.erp_px_cat_g1v2;

SELECT DISTINCT
    subcat
FROM bronze.erp_px_cat_g1v2;
