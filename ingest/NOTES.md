# Ingest notes

## Manual step
The CSVs were uploaded by hand to the internal stage `OLIST.RAW.OLIST_STAGE` using the
Snowsight UI, because `PUT` is not supported in worksheets. The CSV files are not
committed to the repo (see `.gitignore`).

## Snowflake setup
- Warehouse: `ELIO_WH` (X-Small, auto-suspend 60s)
- Database: `OLIST`
- Schemas: `RAW`, `STAGING`, `MARTS`
- Role: `ACCOUNTADMIN` (trial account)
- Scripts: `01_setup.sql` (objects, file format, stage), `02_raw_load.sql` (tables and `COPY INTO`)

## Load approach
- File format `CSV_FF`: UTF-8, header row skipped, quoted fields supported (review
  comments contain commas and line breaks), empty strings loaded as NULL.
- All raw columns are loaded as VARCHAR ("as-is, no cleaning"), so a bad date or number
  can never fail the load. Types are cast in the dbt staging layer.
- Metadata captured on every row: `_source_file` (`METADATA$FILENAME`) and `_loaded_at`.
- `ON_ERROR = 'ABORT_STATEMENT'`, so any malformed row fails the load loudly.

## Results
| Table | Rows loaded |
|---|---|
| orders | 99,441 |
| order_items | 112,650 |
| customers | 99,441 |
| products | 32,951 |
| order_reviews | 99,224 |
| product_category_translation | 71 |

No rows failed to load.

## Encoding check
City names are ASCII in the source. Review comments load as valid UTF-8. A broad check
for "Ã" flagged 424 rows, all of them legitimate all-caps Portuguese (for example "NÃO"
and "DEVOLUÇÃO"). A mojibake-specific check ("Ã£", "Ã§", "Ã©", "Ã³", "Ãº" and the
replacement character) found 0 rows.

## Assumptions
- `customer_id` is generated per order; `customer_unique_id` identifies the actual person.
- `order_items` is keyed by (`order_id`, `order_item_id`).
- Known source quirks to handle in staging: misspelled columns (`product_name_lenght`,
  `product_description_lenght`), products with a null category, and orders with no
  delivery date (not yet delivered or cancelled).

## Not loaded
`olist_order_payments`, `olist_sellers` and `olist_geolocation` are staged but not loaded,
because the planned analysis does not need them.

## Duplicate checks (to be filled in)
- Duplicate `order_id` in orders: _TBC_
- Duplicate `review_id` in reviews: _TBC_
- Orders with more than one review: _TBC_