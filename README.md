# Olist e-commerce pipeline: Snowflake + dbt

Small ELT pipeline and commercial analysis built for Elio's Data & AI Engineer take home task.

Raw CSV files (Olist Brazilian E-Commerce dataset) loaded into Snowflake, cleaned in dbt staging models, shaped into a star schema in marts, and used to produce one concrete commercial recommendation. GitHub Actions workflow rebuilds and tests the project on every pull request.

**Platform:** Snowflake (default given in the brief), with all transformations in dbt.

## Results at a glance

Full write-up and client memo in `analysis_answers.md`.

- **Late deliveries hurt reviews.** Orders delivered on time average 4.29 stars; orders 8+ days late average 1.70. About 6.7% of delivered orders arrive late.
- **Almost nobody buys twice.** Only 3.04% of customers (2,887 of 94,983) place a second order.
- **Recommendation:** a 10% second order offer for happy first time customers, tested against a 50% holdout. Estimated at roughly R$12,000 net revenue per monthly cohort (range R$5,000 to R$19,000), based on an assumed +2 point lift in repeat purchasing, which the test is designed to measure.

## Setup used

| Item | Value |
|---|---|
| Snowflake account | 30-day trial, edition: FILL IN (check your signup email, or write "trial") |
| Cloud / region | FILL IN |
| Warehouse | `ELIO_WH`, X-Small, auto-suspend 60 seconds |
| Database | `OLIST` |
| Schemas | `RAW`, `STAGING`, `MARTS` |
| CI database | `OLIST_CI` (used only by the GitHub Actions workflow) |
| Role | `ACCOUNTADMIN` (trial account; see: Assumptions and shortcuts) |
| Python | 3.10.2 |
| dbt-core / dbt-snowflake | 1.10.23 / 1.10.8 (pinned in `requirements.txt`, stable 1.10 series) |
| dbt packages | `dbt_utils` (see `dbt_project/packages.yml` and `package-lock.yml`) |

## How the repo is organised

```
.github/workflows/
  dbt_ci.yml             CI: runs dbt build on pull requests into main, against OLIST_CI
ingest/                  Snowflake setup, raw load and checks (run in order), plus NOTES.md
dbt_project/
  models/staging/        6 views: cleaning, typing, deduplication, _sources.yml, _staging.yml
  models/marts/          dim_customers, dim_products, fct_order_items (tables), _marts.yml
  macros/                generate_schema_name (use exact schema names)
  packages.yml           dbt package dependencies (dbt_utils)
  profiles.yml.example   connection template using environment variables (dev and ci targets)
docs/data_model.md       3NF ERD, star schema, keys, materialisation reasoning
sql/analytics_queries.sql  Analytics queries run against the marts
analysis_answers.md      Part B: insights, recommendation, caveats, client memo, LLM idea
requirements.txt         Pinned dbt versions
```

## How to reproduce

**1. Python environment**
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

**2. Get the data.** Download Olist dataset via Kaggle and unzip. The pipeline uses six files: orders, order_items, customers, products, order_reviews and product_category_translation.

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

## Continuous integration

`.github/workflows/dbt_ci.yml` runs on every pull request into `main`. It installs the pinned dependencies, creates a profile from `profiles.yml.example`, runs `dbt deps`, then `dbt build --target ci`.

- The `ci` target writes staging and marts into a separate `OLIST_CI` database, so a pull request never overwrites the real `STAGING` and `MARTS` schemas. Sources still read `OLIST.RAW`.
- One-off setup in Snowflake: `CREATE DATABASE IF NOT EXISTS OLIST_CI;`
- One-off setup in GitHub (Settings > Secrets and variables > Actions): four repository secrets named `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_PASSWORD` and `SNOWFLAKE_ROLE`.
- To run it locally: `dbt build --target ci --profiles-dir .` from `dbt_project`.

## Design decisions in brief

- **Raw** is loaded as-is: every column is `VARCHAR`, plus `_source_file` (`METADATA$FILENAME`) and `_loaded_at`. This means a malformed value can never fail the load; types are applied in staging with `try_` casts, so bad values become NULL.
- **Staging** (views) renames, types and deduplicates (`QUALIFY ROW_NUMBER()`), and adds `_source` and `_loaded_at`.
- **Marts** (tables) are a star schema: `fct_order_items` at order-item grain, linked by surrogate key to `dim_customers` (one row per real customer, `customer_unique_id`) and `dim_products`.
- **Keys:** surrogate keys via `dbt_utils.generate_surrogate_key`. Snowflake does not enforce unique or foreign keys, so dbt `unique`, `not_null` and `relationships` tests do it. Details and ERD in `docs/data_model.md`.

## Git workflow

Work was done on feature branches and merged into `main` through pull requests (`feature/pipeline` for the pipeline and analysis, `feature/ci` for the CI workflow), with small commits per logical step. No credentials, `profiles.yml`, `.env` or data files are in the repo.

## Assumptions and shortcuts (given the time limit)

- Only six of the nine files are loaded; payments, sellers and geolocation were not needed for the analysis.
- The upload step is manual (Snowsight UI), not scripted.
- I used `ACCOUNTADMIN` on a trial account for speed, including in CI with a password stored as a GitHub secret. In production I would use separate dev and prod databases, least-privilege roles, and key-pair or OIDC authentication.
- CI builds into an empty `OLIST_CI` database rather than a zero-copy clone of production.
- Staging `relationships` tests use the older `to`/`field` syntax, which dbt 1.10 flags with deprecation warn (marts use the newer `arguments` syntax). runs fine.
- The campaign uplift in Part B is an assumption, labelled as such, to be replaced by a measured result from the proposed test.

## What I would do next

- Harden CI: dedicated CI role, key-pair or OIDC authentication instead of a stored password, and a zero-copy clone of production per pull request.
- Make `fct_order_items` incremental (merge on `order_item_key`) and add dbt snapshot (SCD type 2) on `dim_customers`.
- Source freshness checks and row-count monitoring, plus the production data quality checks listed in `analysis_answers.md`.
- Load payments and sellers to add payment mix and seller-level delivery analysis.
- Classify review comments into complaint themes.