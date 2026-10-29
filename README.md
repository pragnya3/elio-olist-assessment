# Olist e-commerce pipeline: Snowflake + dbt

A small ELT pipeline and commercial analysis built for Elio's Data & AI Engineer take-home.

Raw CSV files (Olist Brazilian E-Commerce dataset) are loaded into Snowflake, cleaned in dbt staging models, shaped into a star schema in marts, and used to produce one concrete commercial recommendation.

**Platform:** Snowflake (the default in the brief), with all transformations in dbt.

## Setup used

| Item | Value |
|---|---|
| Snowflake account | 30-day trial, edition: FILL IN (check your signup email or write "trial") |
| Cloud / region | FILL IN |
| Warehouse | `ELIO_WH`, X-Small, auto-suspend 60 seconds |
| Database | `OLIST` |
| Schemas | `RAW`, `STAGING`, `MARTS` |
| Role | `ACCOUNTADMIN` (trial account; see "Shortcuts") |
| Python | 3.10.2 |
| dbt-core / dbt-snowflake | 1.10.23 / 1.10.8 (pinned in `requirements.txt`) |
| dbt packages | `dbt_utils` (see `dbt_project/packages.yml` and `package-lock.yml`) |

## How the repo is organised

```
ingest/                  Snowflake setup, raw load and checks (run in order), plus NOTES.md
dbt_project/
  models/staging/        6 views: cleaning, typing, deduplication, _sources.yml, _staging.yml
  models/marts/          dim_customers, dim_products, fct_order_items (tables), _marts.yml
  macros/                generate_schema_name (use exact schema names)
  profiles.yml.example   connection template using environment variables
docs/data_model.md       3NF ERD, star schema, keys, materialisation reasoning
sql/analytics_queries.sql  Analytics queries run against the marts
analysis_answers.md      Part B: insights, recommendation, caveats, client memo
requirements.txt         Pinned dbt versions
```

## How to reproduce

**1. Python environment**
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

**2. Get the data.** Download the Olist dataset from Kaggle and unzip it. The pipeline uses six files: orders, order_items, customers, products, order_reviews and product_category_translation.

**3. Create Snowflake objects.** In a Snowsight worksheet, run `ingest/01_setup.sql` (use Run All). It creates the warehouse, database, schemas, a CSV file format and an internal stage `OLIST.RAW.OLIST_STAGE`.

**4. Upload the files (manual step).** In Snowsight go to the database explorer, open `OLIST` > `RAW` > Stages > `OLIST_STAGE`, click **+ Files**, and upload the six CSVs. (The Snowflake CLI or SnowSQL `PUT` command also works.) Check with `LIST @OLIST.RAW.OLIST_STAGE;`.

**5. Load the raw tables.** Run `ingest/02_raw_load.sql` (Run All). Expected row counts: orders 99,441; order_items 112,650; customers 99,441; products 32,951; order_reviews 99,224; translation 71. `ingest/03_duplicate_checks.sql` is an optional check; findings are in `ingest/NOTES.md`.

**6. Configure dbt.** Copy the example profile and set your credentials as environment variables (never commit them; `.env` and `profiles.yml` are git-ignored):
```bash
cp dbt_project/profiles.yml.example dbt_project/profiles.yml
```
Create a `.env` file in the repo root:
```
export SNOWFLAKE_ACCOUNT=orgname-accountname
export SNOWFLAKE_USER=your-username
export SNOWFLAKE_PASSWORD=your-password
export SNOWFLAKE_ROLE=ACCOUNTADMIN
```

**7. Install packages and build.**
```bash
source .env
cd dbt_project
dbt deps --profiles-dir .
dbt build --profiles-dir .
```
A clean run is 3 mart tables, 6 staging views and 39 tests: `PASS=48 ERROR=0`.

**8. Run the analytics queries.** Open `sql/analytics_queries.sql` in a Snowsight worksheet and run each query one at a time (click inside it and press Cmd + Enter).

## Design decisions in brief

- **Raw** is loaded as-is: every column is `VARCHAR`, plus `_source_file` (`METADATA$FILENAME`) and `_loaded_at`. This means a malformed value can never fail the load; types are applied in staging with `try_` casts, so bad values become NULL.
- **Staging** (views) renames, types and deduplicates (`QUALIFY ROW_NUMBER()`), and adds `_source` and `_loaded_at`.
- **Marts** (tables) are a star schema: `fct_order_items` at order-item grain, linked by surrogate key to `dim_customers` (one row per real customer, `customer_unique_id`) and `dim_products`.
- **Keys:** surrogate keys via `dbt_utils.generate_surrogate_key`. Snowflake does not enforce unique or foreign keys, so dbt `unique`, `not_null` and `relationships` tests do it. Details and ERD in `docs/data_model.md`.

## Assumptions and shortcuts (given the time limit)

- Only six of the nine files are loaded; payments, sellers and geolocation were not needed for the analysis.
- The upload step is manual (Snowsight UI), not scripted.
- I used `ACCOUNTADMIN` on a trial account for speed. In production I would use separate dev and prod databases, least-privilege roles and key-pair authentication.
- Staging `relationships` tests use the older `to`/`field` syntax, which dbt 1.10 flags with a deprecation warning (marts use the newer `arguments` syntax). It runs fine.
- The campaign uplift in Part B is an assumption, labelled as such, to be replaced by a measured result from the proposed test.

## What I would do next

- GitHub Actions workflow running `dbt build` on each pull request against a CI schema (zero-copy clone of production).
- Make `fct_order_items` incremental (merge on `order_item_key`) and add a dbt snapshot (SCD type 2) on `dim_customers`.
- Source freshness checks and row-count monitoring, plus the production data quality checks listed in `analysis_answers.md`.
- Load payments and sellers to add payment mix and seller-level delivery analysis.
- Classify review comments into complaint themes with Snowflake Cortex (see B5).