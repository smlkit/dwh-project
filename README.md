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

## Data Mart Model (Star Schema)
![Data Mart](docs/data_model.jpg)
