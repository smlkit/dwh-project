# Data Warehouse Project
Building a Medallion DWH with SQL Server, including ELT processing, data modeling, and analytics.

- `SQL Server Express` as relational database management system
- `SQL Server Management Studio (SSMS)` as IDE for writing and executing T-SQL
- `git` for version control
- `DrawIO` to design data architecture, models, data flows, and diagrams 

## Data Architecture
The data architecture for this project follows Medallion Architecture.
![Data Architecture](docs/data_architecture.jpg)

1. **Bronze Layer**: Stores raw data as-is from the source systems. Data is ingested from CSV Files into SQL Server Database.
2. **Silver Layer**: This layer includes data cleansing, standardization, and normalization processes to prepare data for analysis.
3. **Gold Layer**: Houses business-ready data modeled into a star schema required for reporting and analytics.

## Data Integration
![Data Integration](docs/data_integration.jpg)

The data warehouse integrates information from two source systems: **CRM** and **ERP**.
- **CRM** provides sales transactions and core master data.
- **ERP** enriches this with product categories, customer birthdates, and country information.

### CRM System (Customer Relationship Management)

| Table | Description | Key Fields |
|-------|-------------|------------|
| **`crm_cust_info`** | Customer master data | `cst_id`, `cst_key` |
| **`crm_prd_info`** | Product information (current & historical) | `prd_key` |
| **`crm_sales_details`** | Records about sales and orders | `prd_key`, `cst_id`, `SALES` |

### ERP System (Enterprise Resource Planning)

| Table | Description | Key Fields |
|-------|-------------|------------|
| **`erp_px_cat_g1v2`** | Product categories | `id` |
| **`erp_cust_az12`** | Extra customer information (birthdate) | `cid` |
| **`erp_loc_a101`** | Extra customer information (country) | `cid` |

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

| Column | Description |
|--------|-------------|
| **customer_key** (PK) | Surrogate key uniquely identifying each customer |
| customer_id | Original customer ID from CRM |
| customer_number | Customer alternate key (cst_key) |
| first_name | Customer's first name |
| last_name | Customer's last name |
| country | Customer's country from ERP |
| gender | Customer's gender (CRM as primary source, ERP as fallback) |
| marital_status | Customer's marital status |
| birthdate | Customer's birthdate from ERP |
| create_date | Record creation date from CRM |

#### `dim_products` (Product Dimension)

| Column | Description |
|--------|-------------|
| **product_key** (PK) | Surrogate key uniquely identifying each product |
| product_id | Original product ID from CRM |
| product_number | Product alternate key (prd_key) |
| product_name | Product name |
| product_cost | Product cost |
| product_line | Product line category |
| category_id | Category identifier from ERP |
| category | Product category from ERP |
| subcategory | Product subcategory from ERP |
| maintenance | Maintenance category from ERP |
| start_date | Product start date |

#### `fact_sales` (Sales Fact Table)

| Column | Description |
|--------|-------------|
| order_number | Unique order identifier |
| **product_key** (FK) | References `dim_products.product_key` |
| **customer_key** (FK) | References `dim_customers.customer_key` |
| order_date | Date the order was placed |
| shipping_date | Date the order was shipped |
| due_date | Date the order was due |
| sales_amount | Total sales amount (recalculated to ensure consistency) |
| quantity | Number of units sold |
| sls_price | Price per unit |
