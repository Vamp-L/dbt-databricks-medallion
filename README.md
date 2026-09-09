# dbt Databricks Medallion Project

A data transformation project built using **dbt Core** and **Databricks** with a **Medallion Architecture** consisting of Bronze, Silver, and Gold layers.

This project demonstrates a modern ELT workflow using dbt for data transformation, testing, reusable SQL logic, schema management, seeds, snapshots, and analytics-ready data preparation.

## Project Overview

The main objective of this project is to transform source data stored in Databricks into structured datasets that can be used for analytics.

The workflow follows:

```text
Source Data
    ↓
Databricks Source Schema
    ↓
Bronze Layer
    ↓
Silver Layer
    ↓
Gold Layer
    ↓
Analytics / BI
```

The Medallion Architecture used in this project consists of:

- **Bronze Layer** — raw or lightly transformed data
- **Silver Layer** — cleaned, joined, standardized, and aggregated data
- **Gold Layer** — analytics-ready and business-focused datasets

## Tech Stack

- dbt Core
- Databricks
- Databricks SQL
- SQL
- Jinja
- Python
- uv
- Git
- GitHub

## Architecture

```text
External / Source Data
        ↓
Databricks Catalog
`dbt_tutorial_dev.source`
        ↓
dbt `source()`
        ↓
Bronze Models
        ↓
Silver Models
        ↓
Gold Models
        ↓
Analytics-ready Data
```

Example flow:

```text
source.fact_sales
        ↓
bronze_sales
        ↓
silver_salesinfo
        ↓
Gold / Analytical Models
```

## Project Structure

```text
dbt-databricks-medallion/
│
├── vamp_dbt/
│   ├── analyses/
│   │   ├── jinja_1.sql
│   │   ├── jinja_2.sql
│   │   ├── jinja_3.sql
│   │   └── query_macro.sql
│   │
│   ├── macros/
│   │   ├── generate_schema.sql
│   │   └── multiply.sql
│   │
│   ├── models/
│   │   ├── bronze/
│   │   │   ├── bronze_customer.sql
│   │   │   ├── bronze_date.sql
│   │   │   ├── bronze_product.sql
│   │   │   ├── bronze_returns.sql
│   │   │   ├── bronze_sales.sql
│   │   │   ├── bronze_store.sql
│   │   │   └── properties.yml
│   │   │
│   │   ├── silver/
│   │   │   ├── silver_returnsinfo.sql
│   │   │   └── silver_salesinfo.sql
│   │   │
│   │   ├── gold/
│   │   │   └── source_gold_items.sql
│   │   │
│   │   └── source/
│   │       └── sources.yml
│   │
│   ├── seeds/
│   │   └── lookup.csv
│   │
│   ├── snapshots/
│   │   └── gold_items.yml
│   │
│   ├── tests/
│   │   └── non_negative_test.sql
│   │
│   └── dbt_project.yml
│
├── pyproject.toml
├── requirements.txt
├── uv.lock
└── README.md
```

## Source Layer

Source tables are stored in Databricks under:

```text
Catalog: dbt_tutorial_dev
Schema: source
```

The source tables are declared inside:

```text
vamp_dbt/models/source/sources.yml
```

Example:

```yaml
sources:
  - name: source
    database: dbt_tutorial_dev
    schema: source
    tables:
      - name: fact_sales
      - name: fact_returns
      - name: dim_date
      - name: dim_store
      - name: dim_product
      - name: dim_customer
      - name: items
```

The source tables can then be referenced inside dbt models using:

```sql
{{ source('source', 'fact_sales') }}
```

Example:

```sql
SELECT *
FROM {{ source('source', 'fact_sales') }}
```

## Bronze Layer

The Bronze layer contains raw or lightly transformed data from the source schema.

Models currently included:

```text
bronze_customer
bronze_date
bronze_product
bronze_returns
bronze_sales
bronze_store
```

Example Bronze model:

```sql
SELECT *
FROM {{ source('source', 'fact_sales') }}
```

The Bronze layer is configured inside `dbt_project.yml`:

```yaml
models:
  vamp_dbt:
    bronze:
      +materialized: table
      +schema: bronze
```

The resulting tables are created inside:

```text
dbt_tutorial_dev.bronze
```

## Silver Layer

The Silver layer contains cleaned and transformed datasets.

Transformations in this layer include:

- joining multiple Bronze models
- calculating derived columns
- aggregation
- data cleaning
- standardization
- preparation for analytics

### Silver Sales Information

The `silver_salesinfo` model combines sales, product, and customer data.

Example:

```sql
WITH sales AS (
    SELECT
        sales_id,
        product_sk,
        customer_sk,
        {{ multiply('unit_price', 'quantity') }} AS gross_amount,
        payment_method
    FROM {{ ref('bronze_sales') }}
),

products AS (
    SELECT
        product_sk,
        category
    FROM {{ ref('bronze_product') }}
),

customers AS (
    SELECT
        customer_sk,
        gender
    FROM {{ ref('bronze_customer') }}
),

joined_query AS (
    SELECT
        sales.sales_id,
        sales.gross_amount,
        sales.payment_method,
        products.category,
        customers.gender
    FROM sales
    JOIN products
        ON sales.product_sk = products.product_sk
    JOIN customers
        ON sales.customer_sk = customers.customer_sk
)

SELECT
    category,
    gender,
    SUM(gross_amount) AS total_sales
FROM joined_query
GROUP BY
    category,
    gender
ORDER BY
    total_sales DESC
```

This model demonstrates:

- CTEs
- joins
- aggregation
- dbt `ref()`
- Jinja macros

### Silver Returns Information

The `silver_returnsinfo` model combines return transaction data with product information.

Example:

```sql
WITH returned AS (
    SELECT
        product_sk,
        return_reason,
        refund_amount
    FROM {{ ref('bronze_returns') }}
),

product AS (
    SELECT
        product_sk,
        product_name,
        category
    FROM {{ ref('bronze_product') }}
),

joined_query AS (
    SELECT
        product.product_name,
        product.category,
        returned.return_reason,
        returned.refund_amount
    FROM returned
    JOIN product
        ON returned.product_sk = product.product_sk
)

SELECT
    product_name,
    category,
    return_reason,
    ROUND(SUM(refund_amount), 2) AS total_refunds
FROM joined_query
GROUP BY
    product_name,
    category,
    return_reason
ORDER BY
    total_refunds DESC
```

## Gold Layer

The Gold layer is intended for analytics-ready and business-focused datasets.

One example implemented in this project is item deduplication.

```sql
WITH deduplicated_items AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY id
            ORDER BY updateDate DESC
        ) AS deduplication_rank
    FROM {{ source('source', 'items') }}
)

SELECT
    id,
    name,
    category,
    updateDate
FROM deduplicated_items
WHERE deduplication_rank = 1
```

This logic keeps only the latest record for each `id`.

The deduplication process works like this:

```text
PARTITION BY id
→ group records by ID

ORDER BY updateDate DESC
→ newest record first

ROW_NUMBER()
→ assign ranking

rank = 1
→ keep the newest record
```

## Jinja

Jinja is used in this project to make SQL more dynamic and reusable.

Examples include:

- variables
- loops
- conditions
- macros
- dbt functions

Example variable:

```jinja
{% set cols_list = [
    "sales_id",
    "date_sk",
    "gross_amount"
] %}
```

Example loop:

```jinja
{% for col in cols_list %}
    {{ col }}
    {% if not loop.last %}
        ,
    {% endif %}
{% endfor %}
```

## Custom Macros

### Multiply Macro

The project includes a reusable macro for multiplication.

```jinja
{% macro multiply(column1, column2) %}
    {{ column1 }} * {{ column2 }}
{% endmacro %}
```

Usage:

```sql
{{ multiply('unit_price', 'quantity') }} AS gross_amount
```

Compiled SQL:

```sql
unit_price * quantity AS gross_amount
```

## Custom Schema Generation

The project uses a custom `generate_schema_name` macro.

```jinja
{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- set default_schema = target.schema -%}

    {%- if custom_schema_name is none -%}

        {{ default_schema }}

    {%- else -%}

        {{ custom_schema_name | trim }}

    {%- endif -%}

{%- endmacro %}
```

This allows dbt models to be created directly inside schemas such as:

```text
bronze
silver
gold
```

instead of using generated names such as:

```text
default_bronze
default_silver
default_gold
```

## Seeds

The project uses dbt seeds for small static reference datasets.

Example:

```text
vamp_dbt/seeds/lookup.csv
```

Example data:

```csv
customer_id,customer_name,customer_email
1,John Doe,john.doe@example.com
2,Jane Smith,jane.smith@example.com
3,Bob Johnson,bob.johnson@example.com
```

Run seeds using:

```bash
dbt seed
```

The seed schema is configured in `dbt_project.yml`:

```yaml
seeds:
  vamp_dbt:
    +schema: bronze
```

## Data Testing

The project demonstrates both generic and singular dbt tests.

### Generic Tests

Generic tests can be configured inside YAML files.

Example:

```yaml
columns:
  - name: customer_id
    tests:
      - not_null
      - unique
```

Common generic dbt tests include:

```text
not_null
unique
relationships
accepted_values
```

### Singular Tests

Singular tests are custom SQL queries stored inside the `tests/` directory.

Example:

```sql
SELECT *
FROM {{ ref('bronze_sales') }}
WHERE gross_amount < 0
```

A singular test passes when the query returns:

```text
0 rows
```

If rows are returned, the test fails.

## Snapshots

Snapshots are used to track historical changes in records over time.

They are useful for concepts such as:

```text
Slowly Changing Dimension Type 2
```

Possible use cases include:

- customer address changes
- employee department changes
- product category changes
- store region changes

Snapshots preserve previous record versions instead of simply overwriting them.

## dbt Commands Used

Check project connection and configuration:

```bash
dbt debug
```

Parse the project:

```bash
dbt parse
```

List models:

```bash
dbt ls --resource-type model
```

Run all models:

```bash
dbt run
```

Run a specific model:

```bash
dbt run --select silver_salesinfo
```

Load seeds:

```bash
dbt seed
```

Run tests:

```bash
dbt test
```

Build models, seeds, snapshots, and tests:

```bash
dbt build
```

Clean generated dbt files:

```bash
dbt clean
```

## Development Workflow

Typical development workflow:

```text
Create / Update Model
        ↓
dbt parse
        ↓
dbt run
        ↓
dbt test
        ↓
git add
        ↓
git commit
        ↓
git push
```

Feature branch workflow:

```text
main
  ↓
feature branch
  ↓
development
  ↓
commit
  ↓
merge
  ↓
main
```

Example:

```bash
git switch -c feature/silver-models

git add .
git commit -m "add silver models"

git switch main
git merge feature/silver-models

git push
```

## Security

Sensitive credentials are not committed to this repository.

Files such as Databricks credentials and local environment files are excluded using `.gitignore`.

Example:

```gitignore
.venv/

.env
.env.*

vamp_dbt/profiles.yml

logs/
vamp_dbt/target/
vamp_dbt/logs/
vamp_dbt/dbt_packages/

.vscode/
.idea/
```

Databricks API tokens should never be stored directly inside a public GitHub repository.

Environment variables should be used for credentials where possible.

Example:

```yaml
token: "{{ env_var('DATABRICKS_TOKEN') }}"
```

## Future Improvements

Planned improvements include:

- incremental dbt models
- advanced data quality tests
- additional Gold-layer models
- dimensional data modeling
- fact and dimension tables
- Slowly Changing Dimension implementation
- CI/CD using GitHub Actions
- dbt documentation generation
- automated Databricks workflows
- Power BI integration
- development and production environment separation

## Learning Objectives

This project was created to practice and demonstrate:

- ELT workflow
- dbt project structure
- Databricks integration
- Medallion Architecture
- SQL transformations
- CTEs
- SQL joins
- aggregation
- deduplication
- Jinja templating
- dbt macros
- dbt sources
- dbt seeds
- dbt tests
- dbt snapshots
- custom schema configuration
- Git branching
- version control
- data quality validation
- dimensional data modeling concepts

## Author

**Vamp-L**

Data Engineering learning project focused on building practical experience with **dbt, Databricks, SQL, Jinja, Git, and modern analytics engineering workflows**.
