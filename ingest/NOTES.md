# Ingest notes

## Manual step
CSVs were uploaded to the internal stage OLIST.RAW.OLIST_STAGE via the Snowsight
UI (PUT is not supported in worksheets). Files are not committed to the repo.

## Load approach
- File format CSV_FF: UTF-8, header skipped, quoted fields, empty strings as NULL.
- All raw columns loaded as VARCHAR ("as-is, no cleaning"), so a bad date or
  number can never fail the load. Types are cast in staging.
- Metadata added per row: _source_file (METADATA$FILENAME), _loaded_at.
- ON_ERROR = ABORT_STATEMENT: any malformed row fails the load loudly.

## Results
| Table | Rows loaded |
|---|---|
| orders | 99,441 |
| order_items | 112,650 |
| customers | 99,441 |
| products | 32,951 |
| order_reviews | 99,224 |
| product_category_translation | 71 |

No rows failed to load. Portuguese characters checked and render correctly.

## Assumptions
- customer_id is one per order; customer_unique_id identifies the actual person.
- order_items key is (order_id, order_item_id).
- Known source quirks to handle in staging: misspelled columns
  (product_name_lenght, product_description_lenght), some products with null
  category, and orders without delivery dates (not delivered).

## Not loaded
payments, sellers, geolocation (not needed for the planned analysis).
