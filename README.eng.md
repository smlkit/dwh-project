# Data Warehouse Project

Building a Medallion DWH with SQL Server, including ELT processing, data modeling, and analytics.

- `SQL Server Express` as relational database management system
- `SQL Server Management Studio (SSMS)` as IDE for writing and executing T-SQL
- `git` for version control
- `DrawIO` to design data architecture, models, data flows, and diagrams

## Data Architecture

![Data Architecture](docs/data_architecture.jpg)

The data architecture for this project follows Medallion Architecture.

1. **Bronze Layer**: Stores raw data as-is from the source systems. Data is ingested from CSV Files into SQL Server Database.
2. **Silver Layer**: This layer includes data cleansing, standardization, and normalization processes to prepare data for analysis.
3. **Gold Layer**: Houses business-ready data modeled into a star schema required for reporting and analytics.

## Data Integration

![Data Integration](docs/data_integration.jpg)

The data warehouse integrates information from two source systems: **CRM** and **ERP**.

- **CRM** provides sales transactions and core master data.
- **ERP** enriches this with product categories, customer birthdates, and country information.

### CRM System (Customer Relationship Management)

| Table                   | Description                                | Key Fields                   |
| ----------------------- | ------------------------------------------ | ---------------------------- |
| **`crm_cust_info`**     | Customer master data                       | `cst_id`, `cst_key`          |
| **`crm_prd_info`**      | Product information (current & historical) | `prd_key`                    |
| **`crm_sales_details`** | Records about sales and orders             | `prd_key`, `cst_id`, `SALES` |

### ERP System (Enterprise Resource Planning)

| Table                 | Description                            | Key Fields |
| --------------------- | -------------------------------------- | ---------- |
| **`erp_px_cat_g1v2`** | Product categories                     | `id`       |
| **`erp_cust_az12`**   | Extra customer information (birthdate) | `cid`      |
| **`erp_loc_a101`**    | Extra customer information (country)   | `cid`      |

### Integration Logic

**Key Mappings:**

- `crm_prd_info.prd_key` → `erp_px_cat_g1v2.id` (links products to categories)
- `crm_cust_info.cst_key` → `erp_cust_az12.cid` (links customers to birthdate)
- `crm_cust_info.cst_key` → `erp_loc_a101.cid` (links customers to country)
- `crm_sales_details.cst_id` → `crm_cust_info.cst_id` (links sales to customers)
- `crm_sales_details.prd_key` → `crm_prd_info.prd_key` (links sales to products)

## Data Flow

![Data Flow](docs/data_flow.jpg)

`Sources → Bronze (raw copy) → Silver (cleaned/joined) → Gold (aggregated/denormalized)`

### Source Layer

Raw data is extracted from operational systems:

- **CRM System** – Provides sales transactions, customer master, and product master data.
- **ERP System** – Provides supplementary customer attributes (birthdate, country) and product category information.

### Bronze Layer

Data is loaded as-is from external CSV files into the bronze schema using an ETL stored procedure (`bronze.load_bronze`).

- No cleaning, deduplication, or transformations are applied.
- Preserves original data types, formats, and structures.

### Silver Layer

Data is cleaned, deduplicated, and standardized through an ETL stored procedure (`silver.load_silver`).

- Data cleansing includes handling missing values, standardizing formats (e.g., marital status, gender, country), and filtering out invalid records.
- Deduplication is applied to ensure each record is unique (e.g., keeping the latest customer record).
- Key mappings are resolved (e.g., extracting category IDs from product keys, cleaning customer IDs by removing prefixes/special characters).
- Data from CRM and ERP is enriched and standardized to create consistent, integrated tables.

### Gold Layer

Data is aggregated and denormalized into star-schema **fact** and **dimension** tables through views created in the Gold layer.

- Views are created for the final dimension and fact tables following a Star Schema model.
- Data is transformed and combined from the Silver layer to produce clean, enriched, and business-ready datasets.

**Gold Layer Views:**

- `fact_sales` – contains transactional metrics (e.g., sales amount) linked to customer and product keys.
- `dim_customers` – unified customer view (combining CRM customer info + ERP birthdate + country).
- `dim_products` – unified product view (combining CRM product info + ERP category).

## Data Mart Model (Star Schema)

![Data Mart](docs/data_model.jpg)

The Gold layer follows a **Star Schema** model with one fact table and two dimension tables.

#### `dim_customers` (Customer Dimension)

| Column                | Description                                                |
| --------------------- | ---------------------------------------------------------- |
| **customer_key** (PK) | Surrogate key uniquely identifying each customer           |
| customer_id           | Original customer ID from CRM                              |
| customer_number       | Customer alternate key (cst_key)                           |
| first_name            | Customer's first name                                      |
| last_name             | Customer's last name                                       |
| country               | Customer's country from ERP                                |
| gender                | Customer's gender (CRM as primary source, ERP as fallback) |
| marital_status        | Customer's marital status                                  |
| birthdate             | Customer's birthdate from ERP                              |
| create_date           | Record creation date from CRM                              |

#### `dim_products` (Product Dimension)

| Column               | Description                                     |
| -------------------- | ----------------------------------------------- |
| **product_key** (PK) | Surrogate key uniquely identifying each product |
| product_id           | Original product ID from CRM                    |
| product_number       | Product alternate key (prd_key)                 |
| product_name         | Product name                                    |
| product_cost         | Product cost                                    |
| product_line         | Product line category                           |
| category_id          | Category identifier from ERP                    |
| category             | Product category from ERP                       |
| subcategory          | Product subcategory from ERP                    |
| maintenance          | Maintenance category from ERP                   |
| start_date           | Product start date                              |

#### `fact_sales` (Sales Fact Table)

| Column                | Description                                             |
| --------------------- | ------------------------------------------------------- |
| order_number          | Unique order identifier                                 |
| **product_key** (FK)  | References `dim_products.product_key`                   |
| **customer_key** (FK) | References `dim_customers.customer_key`                 |
| order_date            | Date the order was placed                               |
| shipping_date         | Date the order was shipped                              |
| due_date              | Date the order was due                                  |
| sales_amount          | Total sales amount (recalculated to ensure consistency) |
| quantity              | Number of units sold                                    |
| sls_price             | Price per unit                                          |

## 🥉 Bronze Layer – Implementation

The Bronze layer is the first stage of the Medallion Architecture.  
Its only responsibility is to **ingest raw data exactly as it arrives** from the source systems (CRM and ERP) without any transformation, cleaning, or business logic.

### 1. Creating Bronze Tables (DDL)

Before loading data we define the table structures that will hold the raw records.  
Each table mirrors the structure of the corresponding CSV file.

```sql
/*
===============================================================================
DDL Script: Create Bronze Tables
===============================================================================
Script Purpose:
    This script creates tables in the 'bronze' schema, dropping existing tables
    if they already exist.
    Run this script to re-define the DDL structure of 'bronze' Tables
===============================================================================
*/

IF OBJECT_ID('bronze.crm_cust_info', 'U') IS NOT NULL
    DROP TABLE bronze.crm_cust_info;
GO

CREATE TABLE bronze.crm_cust_info (
    cst_id              INT,
    cst_key             NVARCHAR(50),
    cst_firstname       NVARCHAR(50),
    cst_lastname        NVARCHAR(50),
    cst_marital_status  NVARCHAR(50),
    cst_gndr            NVARCHAR(50),
    cst_create_date     DATE
);
GO

IF OBJECT_ID('bronze.crm_prd_info', 'U') IS NOT NULL
    DROP TABLE bronze.crm_prd_info;
GO

CREATE TABLE bronze.crm_prd_info (
    prd_id       INT,
    prd_key      NVARCHAR(50),
    prd_nm       NVARCHAR(50),
    prd_cost     INT,
    prd_line     NVARCHAR(50),
    prd_start_dt DATETIME,
    prd_end_dt   DATETIME
);
GO

IF OBJECT_ID('bronze.crm_sales_details', 'U') IS NOT NULL
    DROP TABLE bronze.crm_sales_details;
GO

CREATE TABLE bronze.crm_sales_details (
    sls_ord_num  NVARCHAR(50),
    sls_prd_key  NVARCHAR(50),
    sls_cust_id  INT,
    sls_order_dt INT,
    sls_ship_dt  INT,
    sls_due_dt   INT,
    sls_sales    INT,
    sls_quantity INT,
    sls_price    INT
);
GO

IF OBJECT_ID('bronze.erp_loc_a101', 'U') IS NOT NULL
    DROP TABLE bronze.erp_loc_a101;
GO

CREATE TABLE bronze.erp_loc_a101 (
    cid    NVARCHAR(50),
    cntry  NVARCHAR(50)
);
GO

IF OBJECT_ID('bronze.erp_cust_az12', 'U') IS NOT NULL
    DROP TABLE bronze.erp_cust_az12;
GO

CREATE TABLE bronze.erp_cust_az12 (
    cid    NVARCHAR(50),
    bdate  DATE,
    gen    NVARCHAR(50)
);
GO

IF OBJECT_ID('bronze.erp_px_cat_g1v2', 'U') IS NOT NULL
    DROP TABLE bronze.erp_px_cat_g1v2;
GO

CREATE TABLE bronze.erp_px_cat_g1v2 (
    id           NVARCHAR(50),
    cat          NVARCHAR(50),
    subcat       NVARCHAR(50),
    maintenance  NVARCHAR(50)
);
GO
```

**Key points of the DDL:**

- Tables are created in the `bronze` schema.
- Existing tables are dropped first (`IF OBJECT_ID ... DROP TABLE`) so the script can be re-run safely.
- Data types and column names stay as close as possible to the source files (no renaming or type conversion at this stage).
- Dates in `crm_sales_details` are stored as `INT` because the source CSV contains them in integer format (YYYYMMDD).

### 2. Loading Data into Bronze (Stored Procedure)

The stored procedure `bronze.load_bronze` performs a full reload of all Bronze tables from CSV files using `BULK INSERT`.

```sql
/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
===============================================================================
Script Purpose:
    This stored procedure loads data into the 'bronze' schema from external CSV files.
    It performs the following actions:
    - Truncates the bronze tables before loading data.
    - Uses the `BULK INSERT` command to load data from csv Files to bronze tables.

Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.

Usage:
    EXEC bronze.load_bronze;
===============================================================================
*/

CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
	BEGIN TRY
		SET @batch_start_time = GETDATE();
		PRINT '=========================================='
		PRINT 'Loading bronze layer...'
		PRINT '=========================================='

		PRINT '------------------------------------------------';
		PRINT 'Loading CRM tables';
		PRINT '------------------------------------------------';

		SET @start_time = GETDATE();
		TRUNCATE TABLE bronze.crm_cust_info;
		PRINT '>> Inserting data into: bronze.crm_cust_info';
		BULK INSERT bronze.crm_cust_info
		FROM 'D:\Study\dwh_project\datasets\source_crm\cust_info.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '-------------';

		SET @start_time = GETDATE();
		TRUNCATE TABLE bronze.crm_prd_info;
		PRINT '>> Inserting data into: bronze.crm_prd_info';
		BULK INSERT bronze.crm_prd_info
		FROM 'D:\Study\dwh_project\datasets\source_crm\prd_info.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '-------------';

		SET @start_time = GETDATE();
		TRUNCATE TABLE bronze.crm_sales_details;
		PRINT '>> Inserting data into: bronze.crm_sales_details';
		BULK INSERT bronze.crm_sales_details
		FROM 'D:\Study\dwh_project\datasets\source_crm\sales_details.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '-------------';

		PRINT '------------------------------------------------';
		PRINT 'Loading ERP tables';
		PRINT '------------------------------------------------';

		SET @start_time = GETDATE();
		TRUNCATE TABLE bronze.erp_loc_a101;
		PRINT '>> Inserting Data Into: bronze.erp_loc_a101';
		BULK INSERT bronze.erp_loc_a101
		FROM 'D:\Study\dwh_project\datasets\source_erp\LOC_A101.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '-------------';

		SET @start_time = GETDATE();
		TRUNCATE TABLE bronze.erp_cust_az12;
		PRINT '>> Inserting Data Into: bronze.erp_cust_az12';
		BULK INSERT bronze.erp_cust_az12
		FROM 'D:\Study\dwh_project\datasets\source_erp\CUST_AZ12.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '-------------';

		SET @start_time = GETDATE();
		TRUNCATE TABLE bronze.erp_px_cat_g1v2;
		PRINT '>> Inserting Data Into: bronze.erp_px_cat_g1v2';
		BULK INSERT bronze.erp_px_cat_g1v2
		FROM 'D:\Study\dwh_project\datasets\source_erp\PX_CAT_G1V2.csv'
		WITH (
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			TABLOCK
		);
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '-------------';

		SET @batch_end_time = GETDATE();
		PRINT '=========================================='
		PRINT 'Loading bronze layer is completed!';
        PRINT 'Total load duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
		PRINT '=========================================='
	END TRY
	BEGIN CATCH
		PRINT '==========================================';
		PRINT 'ERROR OCCURED DURING LOADING BRONZE LAYER!'
		PRINT 'Error Message' + ERROR_MESSAGE();
		PRINT 'Error Message' + CAST (ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error Message' + CAST (ERROR_STATE() AS NVARCHAR);
		PRINT '==========================================';
	END CATCH
END
```

### How the procedure works

| Step | Action                                        | Why it is done                                                                                      |
| ---- | --------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| 1    | `TRUNCATE TABLE`                              | Clears the table completely before each load (full refresh pattern). Faster than `DELETE`.          |
| 2    | `BULK INSERT ... FROM 'path.csv'`             | High-performance load of the entire CSV file.                                                       |
| 3    | `FIRSTROW = 2`                                | Skips the header row of the CSV.                                                                    |
| 4    | `FIELDTERMINATOR = ','`                       | Defines the column separator.                                                                       |
| 5    | `TABLOCK`                                     | Takes a table-level lock for maximum insert speed.                                                  |
| 6    | Timing variables (`@start_time`, `@end_time`) | Measures and prints how long each table took to load.                                               |
| 7    | `TRY...CATCH`                                 | Catches any error, prints detailed information, and prevents the whole batch from failing silently. |

### Execution

```sql
EXEC bronze.load_bronze;
```

### Design decisions of the Bronze layer

- **No transformations** – data is stored exactly as it comes from the source.
- **Full refresh** – every run truncates and reloads the tables (simple and reliable for this project size).
- **Separation by source** – CRM and ERP tables are loaded in separate blocks for better readability and troubleshooting.
- **Logging** – detailed `PRINT` statements help monitor progress and diagnose issues.

## 🥈 Silver Layer – Implementation

The Silver layer is the second stage of the Medallion Architecture.  
Here the raw data from Bronze is **cleaned, standardized, deduplicated and enriched**.  
Business-friendly values replace cryptic codes, invalid dates are fixed, and duplicate records are removed.

### 1. Creating Silver Tables (DDL)

Silver tables have almost the same structure as Bronze, but with important improvements:

- Added `dwh_create_date` column (audit column that records when the row was loaded into Silver).
- Some data types are corrected (e.g. integer dates become real `DATE`).
- New derived columns appear (e.g. `cat_id` extracted from product key).

```sql
/*
===============================================================================
DDL Script: Create Silver Tables
===============================================================================
Script Purpose:
    This script creates tables in the 'silver' schema, dropping existing tables
    if they already exist.
    Run this script to re-define the DDL structure of 'silver' Tables
===============================================================================
*/

IF OBJECT_ID('silver.crm_cust_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_cust_info;
GO

CREATE TABLE silver.crm_cust_info (
    cst_id              INT,
    cst_key             NVARCHAR(50),
    cst_firstname       NVARCHAR(50),
    cst_lastname        NVARCHAR(50),
    cst_marital_status  NVARCHAR(50),
    cst_gndr            NVARCHAR(50),
    cst_create_date     DATE,
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('silver.crm_prd_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_prd_info;
GO

CREATE TABLE silver.crm_prd_info (
    prd_id       INT,
    cat_id       NVARCHAR(50),
    prd_key      NVARCHAR(50),
    prd_nm       NVARCHAR(50),
    prd_cost     INT,
    prd_line     NVARCHAR(50),
    prd_start_dt DATE,
    prd_end_dt   DATE,
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('silver.crm_sales_details', 'U') IS NOT NULL
    DROP TABLE silver.crm_sales_details;
GO

CREATE TABLE silver.crm_sales_details (
    sls_ord_num  NVARCHAR(50),
    sls_prd_key  NVARCHAR(50),
    sls_cust_id  INT,
    sls_order_dt DATE,
    sls_ship_dt  DATE,
    sls_due_dt   DATE,
    sls_sales    INT,
    sls_quantity INT,
    sls_price    INT,
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('silver.erp_loc_a101', 'U') IS NOT NULL
    DROP TABLE silver.erp_loc_a101;
GO

CREATE TABLE silver.erp_loc_a101 (
    cid    NVARCHAR(50),
    cntry  NVARCHAR(50),
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('silver.erp_cust_az12', 'U') IS NOT NULL
    DROP TABLE silver.erp_cust_az12;
GO

CREATE TABLE silver.erp_cust_az12 (
    cid    NVARCHAR(50),
    bdate  DATE,
    gen    NVARCHAR(50),
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('silver.erp_px_cat_g1v2', 'U') IS NOT NULL
    DROP TABLE silver.erp_px_cat_g1v2;
GO

CREATE TABLE silver.erp_px_cat_g1v2 (
    id           NVARCHAR(50),
    cat          NVARCHAR(50),
    subcat       NVARCHAR(50),
    maintenance  NVARCHAR(50),
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);
GO
```

### 2. Loading & Transforming Data (Stored Procedure)

The stored procedure `silver.load_silver` reads from Bronze, applies all cleaning rules, and writes the result into Silver.

```sql
/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to
    populate the 'silver' schema tables from the 'bronze' schema.
	Actions Performed:
		- Truncates Silver tables.
		- Inserts transformed and cleansed data from Bronze into Silver tables.

Parameters:
    None.
	This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC silver.load_silver;
===============================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
	BEGIN TRY
		SET @batch_start_time = GETDATE();
		PRINT '=========================================='
		PRINT 'Loading silver layer...'
		PRINT '=========================================='

		PRINT '------------------------------------------------';
		PRINT 'Loading CRM tables';
		PRINT '------------------------------------------------';

		-- crm_cust_info
		SET @start_time = GETDATE();
		TRUNCATE TABLE silver.crm_cust_info;
		PRINT '>> Inserting data into: silver.crm_cust_info';
		INSERT INTO silver.crm_cust_info (
			cst_id,
			cst_key,
			cst_firstname,
			cst_lastname,
			cst_marital_status,
			cst_gndr,
			cst_create_date
		)
		SELECT
			cst_id,
			cst_key,
			TRIM(cst_firstname) AS cst_firstname,
			TRIM(cst_lastname) AS cst_lastname,
			CASE WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
				 WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
				 ELSE 'n/a'
			END AS cst_marital_status,
			CASE WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
				 WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
				 ELSE 'n/a'
				 END AS cst_gndr,
			cst_create_date
		FROM (
			SELECT
				*,
				ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) AS cst_rank
			FROM bronze.crm_cust_info
			WHERE cst_id IS NOT NULL
		)t
		WHERE cst_rank = 1;
		SET @end_time = GETDATE();
		PRINT '>> Load duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '-------------';

		-- crm_prd_info
		SET @start_time = GETDATE();
		TRUNCATE TABLE silver.crm_prd_info;
		PRINT '>> Inserting data into: silver.crm_prd_info';
		INSERT INTO silver.crm_prd_info (
			prd_id,
			cat_id,
			prd_key,
			prd_nm,
			prd_cost,
			prd_line,
			prd_start_dt,
			prd_end_dt
		)
		SELECT
			prd_id,
			REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
			SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,
			prd_nm,
			ISNULL(prd_cost, 0) AS prd_cost,
			CASE UPPER(TRIM(prd_line))
				 WHEN 'M' THEN 'Mountain'
				 WHEN 'R' THEN 'Road'
				 WHEN 'S' THEN 'Other sales'
				 WHEN 'T' THEN 'Touring'
				 ELSE 'n/a'
			END AS prd_line,
			CAST(prd_start_dt AS DATE) AS prd_start_dt,
			CAST(LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt) - 1 AS DATE) AS prd_end_dt
		FROM bronze.crm_prd_info;
		SET @end_time = GETDATE();
		PRINT '>> Load duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '-------------';

		-- crm_sales_details
		SET @start_time = GETDATE();
		TRUNCATE TABLE silver.crm_sales_details;
		PRINT '>> Inserting data into: silver.crm_sales_details';
		INSERT INTO silver.crm_sales_details (
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			sls_order_dt,
			sls_ship_dt,
			sls_due_dt,
			sls_sales,
			sls_quantity,
			sls_price
		)
		SELECT
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			CASE WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
				 ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
			END AS sls_order_dt,
			CASE WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
				 ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
			END AS sls_ship_dt,
			CASE WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
				 ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
			END AS sls_due_dt,
			CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
				THEN sls_quantity * ABS(sls_price)
				ELSE sls_sales
			END AS sls_sales,
			sls_quantity,
			CASE WHEN sls_price IS NULL OR sls_price <= 0
				THEN sls_sales / NULLIF(sls_quantity, 0)
				ELSE sls_price
			END AS sls_price
		FROM bronze.crm_sales_details;
		PRINT '>> Load duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '-------------';

		PRINT '------------------------------------------------';
		PRINT 'Loading ERP tables';
		PRINT '------------------------------------------------';

		-- erp_cust_az12
		SET @start_time = GETDATE();
		TRUNCATE TABLE silver.erp_cust_az12;
		PRINT '>> Inserting data into: silver.erp_cust_az12';
		INSERT INTO silver.erp_cust_az12 (
			cid,
			bdate,
			gen
		)
		SELECT
			CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
				ELSE cid
			END AS cid,
			CASE WHEN bdate > GETDATE() THEN NULL
				ELSE bdate
			END AS bdate,
			CASE WHEN UPPER(TRIM(gen)) IN ('M', 'Male') THEN 'Male'
				WHEN UPPER(TRIM(gen)) IN ('F', 'Female') THEN 'Female'
				ELSE 'n/a'
			END AS gen
		FROM bronze.erp_cust_az12;
		SET @end_time = GETDATE();
		PRINT '>> Load duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '-------------';

		-- erp_loc_a101
		SET @start_time = GETDATE();
		TRUNCATE TABLE silver.erp_loc_a101;
		PRINT '>> Inserting data into: silver.erp_loc_a101';
		INSERT INTO silver.erp_loc_a101 (
			cid,
			cntry
		)
		SELECT
			REPLACE(cid, '-', '') AS cid,
			CASE WHEN TRIM(cntry) IN ('DE', 'Germany') THEN 'Germany'
				WHEN TRIM(cntry) IN ('US', 'USA', 'United States') THEN 'United States'
				WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
				ELSE TRIM(cntry)
			END AS cntry
		FROM bronze.erp_loc_a101;
		SET @end_time = GETDATE();
		PRINT '>> Load duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '-------------';

		-- erp_px_cat_g1v2
		SET @start_time = GETDATE();
		TRUNCATE TABLE silver.erp_px_cat_g1v2;
		PRINT '>> Inserting data into: silver.erp_px_cat_g1v2';
		INSERT INTO silver.erp_px_cat_g1v2 (
			id,
			cat,
			subcat,
			maintenance
		)
		SELECT
			id,
			cat,
			subcat,
			maintenance
		FROM bronze.erp_px_cat_g1v2;
		SET @end_time = GETDATE();
		PRINT '>> Load duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '-------------';
	END TRY
	BEGIN CATCH
		PRINT '==========================================';
		PRINT 'ERROR OCCURED DURING LOADING SILVER LAYER!'
		PRINT 'Error Message' + ERROR_MESSAGE();
		PRINT 'Error Message' + CAST (ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error Message' + CAST (ERROR_STATE() AS NVARCHAR);
		PRINT '==========================================';
	END CATCH
END
```

### Key Transformations Explained

| Table                 | Transformation                              | Purpose                                                         |
| --------------------- | ------------------------------------------- | --------------------------------------------------------------- |
| **crm_cust_info**     | `ROW_NUMBER() ... WHERE cst_rank = 1`       | Keep only the latest record per customer (deduplication)        |
|                       | `TRIM` + `CASE` for marital status & gender | Convert codes (`M`/`S`, `F`/`M`) into readable values           |
| **crm_prd_info**      | `SUBSTRING` + `REPLACE`                     | Extract `cat_id` and clean `prd_key`                            |
|                       | `LEAD(...) - 1`                             | Calculate proper `prd_end_dt` (slowly changing dimension logic) |
|                       | `ISNULL(prd_cost, 0)`                       | Replace NULL cost with 0                                        |
| **crm_sales_details** | Integer → `DATE` conversion                 | Fix dates stored as `YYYYMMDD` integers                         |
|                       | Recalculate `sls_sales` / `sls_price`       | Correct inconsistent sales amount and price                     |
| **erp_cust_az12**     | Remove `NAS` prefix                         | Standardize customer IDs                                        |
|                       | Future birthdates → NULL                    | Remove invalid dates                                            |
|                       | Gender standardization                      | Unify `M`/`Male`/`F`/`Female`                                   |
| **erp_loc_a101**      | Remove `-` from `cid`                       | Make IDs joinable with CRM                                      |
|                       | Country name standardization                | Map codes (`DE`, `US`) to full names                            |
| **erp_px_cat_g1v2**   | Almost pass-through                         | Data was already clean                                          |

### Execution

```sql
EXEC silver.load_silver;
```

### Design decisions of the Silver layer

- **Full refresh** again – tables are truncated and reloaded on every run.
- **All business rules are centralized** inside one stored procedure → easy to maintain and audit.
- **Audit column** `dwh_create_date` is automatically populated.
- **No joins between CRM and ERP yet** – that will happen later in the Gold layer.

## 🥇 Gold Layer – Implementation

The Gold layer is the final stage of the Medallion Architecture.  
It presents **business-ready data** modelled as a classic **Star Schema** (one Fact table + two Dimension tables).

Instead of physical tables we create **views**.  
This approach has several advantages:

- No data duplication
- Always reflects the latest cleaned data from Silver
- Easy to change business logic without reloading data

### Creating Gold Views (DDL + Logic)

```sql
/*
===============================================================================
DDL script: create gold views
===============================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse.
    The Gold layer represents the final dimension and fact tables (Star Schema)

    Each view performs transformations and combines data from the Silver layer
    to produce a clean, enriched, and business-ready dataset.

Usage:
    - These views can be queried directly for analytics and reporting.
===============================================================================
*/

-- Create Dimension: gold.dim_customers
IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
    DROP VIEW gold.dim_customers;
GO
CREATE VIEW gold.dim_customers AS
SELECT
	ROW_NUMBER() OVER(ORDER BY ci.cst_id) AS customer_key,
	ci.cst_id AS customer_id,
	ci.cst_key AS customer_number,
	ci.cst_firstname AS first_name,
	ci.cst_lastname AS last_name,
	la.cntry AS country,
	CASE WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr -- Use CRM is the primary source for gender, ERP as fallback
		ELSE COALESCE(ca.gen, 'n/a')
	END AS gender,
	ci.cst_marital_status AS marital_status,
	ca.bdate AS birthdate,
	ci.cst_create_date AS create_date
FROM silver.crm_cust_info AS ci
LEFT JOIN silver.erp_cust_az12 AS ca
	ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 AS la
	ON la.cid = ci.cst_key;
GO

-- Create Dimension: gold.dim_products
IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;
GO
CREATE VIEW gold.dim_products AS
SELECT
	ROW_NUMBER() OVER(ORDER BY pn.prd_start_dt, pn.prd_key) AS product_key,
	pn.prd_id AS product_id,
	pn.prd_key AS product_number,
	pn.prd_nm AS product_name,
	pn.prd_cost AS product_cost,
	pn.prd_line AS product_line,
	pn.cat_id AS category_id,
	pc.cat AS category,
	pc.subcat AS subcategory,
	pc.maintenance,
	pn.prd_start_dt AS start_date
FROM silver.crm_prd_info AS pn
LEFT JOIN silver.erp_px_cat_g1v2 AS pc
ON pn.cat_id = pc.id
WHERE pn.prd_end_dt IS NULL; -- Filter out all historical data
GO

-- Create Fact Table: gold.fact_sales
IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
    DROP VIEW gold.fact_sales;
GO
CREATE VIEW gold.fact_sales AS
SELECT
	sd.sls_ord_num AS order_number,
	pr.product_key,
	cu.customer_key,
	sd.sls_order_dt AS order_date,
	sd.sls_ship_dt AS shipping_date,
	sd.sls_due_dt AS due_date,
	sd.sls_sales AS sales_amount,
	sd.sls_quantity AS quantity,
	sd.sls_price
FROM silver.crm_sales_details AS sd
LEFT JOIN gold.dim_products AS pr
ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers AS cu
ON cu.customer_id = sd.sls_cust_id;
GO
```

### What each view does

#### 1. `gold.dim_customers`

| Feature       | Implementation                                                                            |
| ------------- | ----------------------------------------------------------------------------------------- |
| Surrogate key | `ROW_NUMBER() OVER(ORDER BY ci.cst_id)` → `customer_key`                                  |
| Integration   | Joins CRM customer data with ERP birthdate (`erp_cust_az12`) and country (`erp_loc_a101`) |
| Gender logic  | CRM is the primary source; if CRM has `'n/a'`, ERP gender is used as fallback             |
| Result        | One clean, enriched row per customer                                                      |

#### 2. `gold.dim_products`

| Feature               | Implementation                                                            |
| --------------------- | ------------------------------------------------------------------------- |
| Surrogate key         | `ROW_NUMBER() OVER(ORDER BY pn.prd_start_dt, pn.prd_key)` → `product_key` |
| Integration           | Joins product data with ERP categories (`erp_px_cat_g1v2`)                |
| Current products only | `WHERE pn.prd_end_dt IS NULL` – historical versions are filtered out      |
| Result                | One current, enriched row per product                                     |

#### 3. `gold.fact_sales`

| Feature      | Implementation                                               |
| ------------ | ------------------------------------------------------------ |
| Grain        | One row = one sales transaction (order line)                 |
| Foreign keys | `product_key` and `customer_key` link to the dimension views |
| Measures     | `sales_amount`, `quantity`, `sls_price`                      |
| Dates        | `order_date`, `shipping_date`, `due_date`                    |

### How the Star Schema works

```
                    ┌─────────────────────┐
                    │  gold.dim_customers │
                    │  (customer_key PK)  │
                    └──────────┬──────────┘
                               │
                               │ customer_key (FK)
                               │
┌────────────────────┐         │         ┌────────────────────┐
│ gold.dim_products  │◄────────┼────────►│  gold.fact_sales   │
│ (product_key PK)   │ product_key (FK)  │                    │
└────────────────────┘                   └────────────────────┘
```

- **Dimensions** contain descriptive attributes (who, what, where).
- **Fact** contains the measurable events (sales) and foreign keys to the dimensions.
- Analysts can now write simple, readable queries without worrying about joins between CRM and ERP.

### Design decisions of the Gold layer

- **Views instead of tables** – always up-to-date, no extra storage, easy to change logic.
- **Surrogate keys** (`customer_key`, `product_key`) – protect the model from changes in source system keys.
- **CRM is the master** for most attributes; ERP is used only for enrichment.
- **Current products only** in `dim_products` – historical SCD versions stay in Silver if needed later.
- **No business aggregations** inside the views – aggregations are left to the reporting layer (Power BI, Tableau, or SQL queries).
