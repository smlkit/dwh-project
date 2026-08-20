# dwh-project
Building a Medallion DWH with SQL Server, including ELT processing, data modeling, and analytics.

## Data Architecture
The data architecture for this project follows Medallion Architecture.
![Data Architecture](docs/data_architecture.jpg)
1. **Bronze Layer**: Stores raw data as-is from the source systems. Data is ingested from CSV Files into SQL Server Database.
2. **Silver Layer**: This layer includes data cleansing, standardization, and normalization processes to prepare data for analysis.
3. **Gold Layer**: Houses business-ready data modeled into a star schema required for reporting and analytics.

## Data Integration
![Data Integration](docs/data_integration.jpg)

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
