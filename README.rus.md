# Проект хранилища данных

Создание DWH на SQL Server по архитектуре "медальон", включая ELT-обработку, моделирование данных и аналитику.

- `SQL Server Express` — система управления реляционными базами данных
- `SQL Server Management Studio (SSMS)` — IDE для написания и выполнения T-SQL
- `git` — система контроля версий
- `DrawIO` — инструмент для проектирования архитектуры данных, моделей, потоков данных и диаграмм

## Архитектура данных

![Data Architecture](docs/data_architecture.jpg)

Архитектура данных этого проекта следует принципам **Medallion Architecture**.

1. **Bronze Layer (Бронзовый слой)**: Хранит сырые данные «как есть» из исходных систем. Данные загружаются из CSV-файлов в базу данных SQL Server.
2. **Silver Layer (Серебряный слой)**: Включает очистку данных, стандартизацию и нормализацию для подготовки данных к анализу.
3. **Gold Layer (Золотой слой)**: Содержит готовые к бизнес-использованию данные, смоделированные в виде star schema, необходимые для отчётности и аналитики.

## Интеграция данных

![Data Integration](docs/data_integration.jpg)

Хранилище данных интегрирует информацию из двух исходных систем: **CRM** и **ERP**.

- **CRM** предоставляет транзакции продаж и основные мастер-данные.
- **ERP** обогащает их категориями продуктов, датами рождения клиентов и информацией о стране.

### Система CRM (Customer Relationship Management)

| Таблица                 | Описание                                   | Ключевые поля                |
| ----------------------- | ------------------------------------------ | ---------------------------- |
| **`crm_cust_info`**     | Мастер-данные клиентов                     | `cst_id`, `cst_key`          |
| **`crm_prd_info`**      | Информация о продуктах (текущая и история) | `prd_key`                    |
| **`crm_sales_details`** | Записи о продажах и заказах                | `prd_key`, `cst_id`, `SALES` |

### Система ERP (Enterprise Resource Planning)

| Таблица               | Описание                                             | Ключевые поля |
| --------------------- | ---------------------------------------------------- | ------------- |
| **`erp_px_cat_g1v2`** | Категории продуктов                                  | `id`          |
| **`erp_cust_az12`**   | Дополнительная информация о клиентах (дата рождения) | `cid`         |
| **`erp_loc_a101`**    | Дополнительная информация о клиентах (страна)        | `cid`         |

### Логика интеграции

**Ключевые соответствия:**

- `crm_prd_info.prd_key` → `erp_px_cat_g1v2.id` (связывает продукты с категориями)
- `crm_cust_info.cst_key` → `erp_cust_az12.cid` (связывает клиентов с датой рождения)
- `crm_cust_info.cst_key` → `erp_loc_a101.cid` (связывает клиентов со страной)
- `crm_sales_details.cst_id` → `crm_cust_info.cst_id` (связывает продажи с клиентами)
- `crm_sales_details.prd_key` → `crm_prd_info.prd_key` (связывает продажи с продуктами)

## Поток данных

![Data Flow](docs/data_flow.jpg)

`Источники → Bronze (сырая копия) → Silver (очищенные/объединённые) → Gold (агрегированные/денормализованные)`

### Исходный слой (Source Layer)

Сырые данные извлекаются из операционных систем:

- **Система CRM** – предоставляет транзакции продаж, мастер-данные клиентов и продуктов.
- **Система ERP** – предоставляет дополнительные атрибуты клиентов (дата рождения, страна) и информацию о категориях продуктов.

### Bronze Layer (Бронзовый слой)

Данные загружаются «как есть» из внешних CSV-файлов в схему bronze с помощью хранимой процедуры ETL (`bronze.load_bronze`).

- Очистка, дедупликация и преобразования не применяются.
- Сохраняются исходные типы данных, форматы и структуры.

### Silver Layer (Серебряный слой)

Данные очищаются, дедуплицируются и стандартизируются через хранимую процедуру ETL (`silver.load_silver`).

- Очистка данных включает обработку пропущенных значений, стандартизацию форматов (например, семейное положение, пол, страна) и фильтрацию некорректных записей.
- Применяется дедупликация для обеспечения уникальности каждой записи (например, сохранение последней записи клиента).
- Разрешаются ключевые соответствия (например, извлечение ID категорий из ключей продуктов, очистка ID клиентов путём удаления префиксов/спецсимволов).
- Данные из CRM и ERP обогащаются и стандартизируются для создания согласованных, интегрированных таблиц.

### Gold Layer (Золотой слой)

Данные агрегируются и денормализуются в **fact**- и **dimension**-таблицы star-схемы через представления, созданные в Gold-слое.

- Создаются представления для итоговых dimension- и fact-таблиц по модели Star Schema.
- Данные преобразуются и объединяются из Silver-слоя для получения чистых, обогащённых и готовых к бизнесу наборов данных.

**Представления Gold-слоя:**

- `fact_sales` – содержит транзакционные метрики (например, сумму продаж), связанные с ключами клиентов и продуктов.
- `dim_customers` – унифицированное представление клиентов (объединение данных CRM + дата рождения и страна из ERP).
- `dim_products` – унифицированное представление продуктов (объединение данных CRM + категории из ERP).

## Модель Data Mart (Star Schema)

![Data Mart](docs/data_model.jpg)

Gold-слой следует модели **Star Schema** с одной fact-таблицей и двумя dimension-таблицами.

#### `dim_customers` (Измерение клиентов)

| Столбец               | Описание                                                     |
| --------------------- | ------------------------------------------------------------ |
| **customer_key** (PK) | Суррогатный ключ, уникально идентифицирующий каждого клиента |
| customer_id           | Оригинальный ID клиента из CRM                               |
| customer_number       | Альтернативный ключ клиента (cst_key)                        |
| first_name            | Имя клиента                                                  |
| last_name             | Фамилия клиента                                              |
| country               | Страна клиента из ERP                                        |
| gender                | Пол клиента (CRM как основной источник, ERP как запасной)    |
| marital_status        | Семейное положение клиента                                   |
| birthdate             | Дата рождения клиента из ERP                                 |
| create_date           | Дата создания записи из CRM                                  |

#### `dim_products` (Измерение продуктов)

| Столбец              | Описание                                                    |
| -------------------- | ----------------------------------------------------------- |
| **product_key** (PK) | Суррогатный ключ, уникально идентифицирующий каждый продукт |
| product_id           | Оригинальный ID продукта из CRM                             |
| product_number       | Альтернативный ключ продукта (prd_key)                      |
| product_name         | Название продукта                                           |
| product_cost         | Себестоимость продукта                                      |
| product_line         | Линейка продукта                                            |
| category_id          | Идентификатор категории из ERP                              |
| category             | Категория продукта из ERP                                   |
| subcategory          | Подкатегория продукта из ERP                                |
| maintenance          | Категория обслуживания из ERP                               |
| start_date           | Дата начала продукта                                        |

#### `fact_sales` (Таблица фактов продаж)

| Столбец               | Описание                                                         |
| --------------------- | ---------------------------------------------------------------- |
| order_number          | Уникальный идентификатор заказа                                  |
| **product_key** (FK)  | Ссылка на `dim_products.product_key`                             |
| **customer_key** (FK) | Ссылка на `dim_customers.customer_key`                           |
| order_date            | Дата размещения заказа                                           |
| shipping_date         | Дата отгрузки заказа                                             |
| due_date              | Срок выполнения заказа                                           |
| sales_amount          | Общая сумма продаж (пересчитана для обеспечения согласованности) |
| quantity              | Количество проданных единиц                                      |
| sls_price             | Цена за единицу                                                  |

## 🥉 Бронзовый слой – Реализация

Бронзовый слой — это первый этап архитектуры "медальон".  
Его единственная задача — **загрузить сырые данные ровно в том виде, в котором они приходят** из исходных систем (CRM и ERP) без каких-либо преобразований, очистки или бизнес-логики.

### 1. Создание таблиц Bronze (DDL)

Перед загрузкой данных мы определяем структуры таблиц, которые будут хранить сырые записи.  
Каждая таблица повторяет структуру соответствующего CSV-файла.

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

**Ключевые моменты DDL:**

- Таблицы создаются в схеме `bronze`.
- Существующие таблицы сначала удаляются (`IF OBJECT_ID ... DROP TABLE`), чтобы скрипт можно было безопасно перезапускать.
- Типы данных и названия столбцов максимально близки к исходным файлам (на этом этапе нет переименований и преобразований типов).
- Даты в `crm_sales_details` хранятся как `INT`, потому что в исходном CSV они представлены в целочисленном формате (YYYYMMDD).

### 2. Загрузка данных в Bronze (хранимое процедура)

Хранимая процедура `bronze.load_bronze` выполняет полную перезагрузку всех таблиц Bronze из CSV-файлов с помощью `BULK INSERT`.

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

### Как работает процедура

| Шаг | Действие                                        | Зачем это делается                                                                              |
| --- | ----------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| 1   | `TRUNCATE TABLE`                                | Полностью очищает таблицу перед каждой загрузкой (паттерн full refresh). Быстрее, чем `DELETE`. |
| 2   | `BULK INSERT ... FROM 'path.csv'`               | Высокопроизводительная загрузка всего CSV-файла.                                                |
| 3   | `FIRSTROW = 2`                                  | Пропускает строку заголовков CSV.                                                               |
| 4   | `FIELDTERMINATOR = ','`                         | Определяет разделитель столбцов.                                                                |
| 5   | `TABLOCK`                                       | Берёт блокировку на уровне таблицы для максимальной скорости вставки.                           |
| 6   | Переменные времени (`@start_time`, `@end_time`) | Измеряют и выводят, сколько секунд заняла загрузка каждой таблицы.                              |
| 7   | `TRY...CATCH`                                   | Перехватывает любую ошибку, выводит подробную информацию и не даёт всему пакету упасть молча.   |

### Запуск

```sql
EXEC bronze.load_bronze;
```

### Решения для бронзового слоя

- **Никаких преобразований** — данные хранятся ровно в том виде, в котором пришли из источника.
- **Full refresh** — каждый запуск очищает и перезагружает таблицы (простой и надёжный подход для размера этого проекта).
- **Разделение по источникам** — таблицы CRM и ERP загружаются в отдельных блоках для удобства чтения и отладки.
- **Логирование** — подробные `PRINT`-сообщения помогают отслеживать прогресс и диагностировать проблемы.

## 🥈 Серебрянный слой – Реализация

Серебрянный слой — это второй этап архитектуры "медальон".  
Здесь сырые данные из Bronze **очищаются, стандартизируются, дедуплицируются и обогащаются**.  
Криптические коды заменяются понятными значениями, исправляются некорректные даты, удаляются дубликаты.

### 1. Создание таблиц Silver (DDL)

Таблицы Silver почти повторяют структуру Bronze, но с важными улучшениями:

- Добавлен столбец `dwh_create_date` (аудиторский столбец, фиксирующий момент загрузки строки в Silver).
- Некоторые типы данных исправлены (например, целочисленные даты становятся настоящими `DATE`).
- Появляются новые производные столбцы (например, `cat_id`, извлечённый из ключа продукта).

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

### 2. Загрузка и преобразование данных (хранимое процедура)

Хранимая процедура `silver.load_silver` читает данные из Bronze, применяет все правила очистки и записывает результат в Silver.

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

### Ключевые преобразования

| Таблица               | Преобразование                                 | Назначение                                                         |
| --------------------- | ---------------------------------------------- | ------------------------------------------------------------------ |
| **crm_cust_info**     | `ROW_NUMBER() ... WHERE cst_rank = 1`          | Оставить только последнюю запись по каждому клиенту (дедупликация) |
|                       | `TRIM` + `CASE` для семейного положения и пола | Преобразовать коды (`M`/`S`, `F`/`M`) в читаемые значения          |
| **crm_prd_info**      | `SUBSTRING` + `REPLACE`                        | Извлечь `cat_id` и очистить `prd_key`                              |
|                       | `LEAD(...) - 1`                                | Рассчитать корректный `prd_end_dt` (логика SCD)                    |
|                       | `ISNULL(prd_cost, 0)`                          | Заменить NULL-стоимость на 0                                       |
| **crm_sales_details** | Integer → `DATE`                               | Исправить даты, хранившиеся как целые числа `YYYYMMDD`             |
|                       | Пересчёт `sls_sales` / `sls_price`             | Исправить несогласованные сумму продаж и цену                      |
| **erp_cust_az12**     | Удаление префикса `NAS`                        | Стандартизировать ID клиентов                                      |
|                       | Будущие даты рождения → NULL                   | Убрать некорректные даты                                           |
|                       | Стандартизация пола                            | Унифицировать `M`/`Male`/`F`/`Female`                              |
| **erp_loc_a101**      | Удаление `-` из `cid`                          | Сделать ID пригодными для join с CRM                               |
|                       | Стандартизация названий стран                  | Преобразовать коды (`DE`, `US`) в полные названия                  |
| **erp_px_cat_g1v2**   | Почти без изменений                            | Данные уже были чистыми                                            |

### Запуск

```sql
EXEC silver.load_silver;
```

### Решения для серебрянного слоя

- **Full refresh** снова — таблицы очищаются и перезагружаются при каждом запуске.
- **Все бизнес-правила централизованы** внутри одной хранимой процедуры → легко поддерживать и аудировать.
- **Аудиторский столбец** `dwh_create_date` заполняется автоматически.
- **Пока нет join’ов между CRM и ERP** — они появятся позже в Gold-слое.

## 🥇 Золотой слой – Реализация

Золотой слой — это финальный этап архитектуры "медальон".  
Он представляет **готовые к бизнесу данные** в классической модели **Star Schema** (одна Fact-таблица + две Dimension-таблицы).

Вместо физических таблиц мы создаём **представления (views)**.  
Такой подход даёт несколько преимуществ:

- Нет дублирования данных
- Всегда отражает актуальные очищенные данные из Silver
- Легко менять бизнес-логику без перезагрузки данных

### Создание представлений Gold (DDL + логика)

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

### Что делает каждое представление

#### 1. `gold.dim_customers`

| Особенность      | Реализация                                                            |
| ---------------- | --------------------------------------------------------------------- |
| Суррогатный ключ | `ROW_NUMBER() OVER(ORDER BY ci.cst_id)` → `customer_key`              |
| Интеграция       | Объединяет данные клиентов CRM с датой рождения (ERP) и страной (ERP) |
| Логика пола      | CRM — основной источник; если в CRM `'n/a'`, берётся пол из ERP       |
| Результат        | Одна чистая, обогащённая строка на каждого клиента                    |

#### 2. `gold.dim_products`

| Особенность                | Реализация                                                                |
| -------------------------- | ------------------------------------------------------------------------- |
| Суррогатный ключ           | `ROW_NUMBER() OVER(ORDER BY pn.prd_start_dt, pn.prd_key)` → `product_key` |
| Интеграция                 | Объединяет данные продуктов с категориями из ERP                          |
| Только актуальные продукты | `WHERE pn.prd_end_dt IS NULL` — исторические версии отфильтровываются     |
| Результат                  | Одна актуальная, обогащённая строка на каждый продукт                     |

#### 3. `gold.fact_sales`

| Особенность   | Реализация                                                          |
| ------------- | ------------------------------------------------------------------- |
| Зерно (grain) | Одна строка = одна транзакция продажи (строка заказа)               |
| Внешние ключи | `product_key` и `customer_key` ссылаются на dimension-представления |
| Меры          | `sales_amount`, `quantity`, `sls_price`                             |
| Даты          | `order_date`, `shipping_date`, `due_date`                           |

### Как работает Star Schema

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

- **Dimensions** содержат описательные атрибуты (кто, что, где).
- **Fact** содержит измеримые события (продажи) и внешние ключи на измерения.
- Аналитики теперь могут писать простые, читаемые запросы, не беспокоясь о join’ах между CRM и ERP.

### Решения для золотого слоя

- **Представления вместо таблиц** — всегда актуальны, не занимают лишнего места, легко менять логику.
- **Суррогатные ключи** (`customer_key`, `product_key`) — защищают модель от изменений ключей в исходных системах.
- **CRM — основной источник** большинства атрибутов; ERP используется только для обогащения.
- **Только актуальные продукты** в `dim_products` — исторические версии SCD остаются в Silver, если понадобятся позже.
- **Нет бизнес-агрегаций** внутри представлений — агрегации оставляются слою отчётности (Power BI, Tableau или SQL-запросам).
