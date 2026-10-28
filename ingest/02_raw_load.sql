USE WAREHOUSE ELIO_WH;
USE SCHEMA OLIST.RAW;

-- ORDERS
CREATE OR REPLACE TABLE OLIST.RAW.ORDERS (
  order_id VARCHAR, customer_id VARCHAR, order_status VARCHAR,
  order_purchase_timestamp VARCHAR, order_approved_at VARCHAR,
  order_delivered_carrier_date VARCHAR, order_delivered_customer_date VARCHAR,
  order_estimated_delivery_date VARCHAR,
  _source_file VARCHAR, _loaded_at TIMESTAMP_NTZ
);
COPY INTO OLIST.RAW.ORDERS
FROM (SELECT $1,$2,$3,$4,$5,$6,$7,$8, METADATA$FILENAME, CURRENT_TIMESTAMP()
      FROM @OLIST.RAW.OLIST_STAGE/olist_orders_dataset.csv)
ON_ERROR = 'ABORT_STATEMENT';

-- ORDER ITEMS
CREATE OR REPLACE TABLE OLIST.RAW.ORDER_ITEMS (
  order_id VARCHAR, order_item_id VARCHAR, product_id VARCHAR, seller_id VARCHAR,
  shipping_limit_date VARCHAR, price VARCHAR, freight_value VARCHAR,
  _source_file VARCHAR, _loaded_at TIMESTAMP_NTZ
);
COPY INTO OLIST.RAW.ORDER_ITEMS
FROM (SELECT $1,$2,$3,$4,$5,$6,$7, METADATA$FILENAME, CURRENT_TIMESTAMP()
      FROM @OLIST.RAW.OLIST_STAGE/olist_order_items_dataset.csv)
ON_ERROR = 'ABORT_STATEMENT';

-- CUSTOMERS
CREATE OR REPLACE TABLE OLIST.RAW.CUSTOMERS (
  customer_id VARCHAR, customer_unique_id VARCHAR, customer_zip_code_prefix VARCHAR,
  customer_city VARCHAR, customer_state VARCHAR,
  _source_file VARCHAR, _loaded_at TIMESTAMP_NTZ
);
COPY INTO OLIST.RAW.CUSTOMERS
FROM (SELECT $1,$2,$3,$4,$5, METADATA$FILENAME, CURRENT_TIMESTAMP()
      FROM @OLIST.RAW.OLIST_STAGE/olist_customers_dataset.csv)
ON_ERROR = 'ABORT_STATEMENT';

-- PRODUCTS
CREATE OR REPLACE TABLE OLIST.RAW.PRODUCTS (
  product_id VARCHAR, product_category_name VARCHAR,
  product_name_lenght VARCHAR, product_description_lenght VARCHAR,
  product_photos_qty VARCHAR, product_weight_g VARCHAR, product_length_cm VARCHAR,
  product_height_cm VARCHAR, product_width_cm VARCHAR,
  _source_file VARCHAR, _loaded_at TIMESTAMP_NTZ
);
COPY INTO OLIST.RAW.PRODUCTS
FROM (SELECT $1,$2,$3,$4,$5,$6,$7,$8,$9, METADATA$FILENAME, CURRENT_TIMESTAMP()
      FROM @OLIST.RAW.OLIST_STAGE/olist_products_dataset.csv)
ON_ERROR = 'ABORT_STATEMENT';

-- REVIEWS
CREATE OR REPLACE TABLE OLIST.RAW.ORDER_REVIEWS (
  review_id VARCHAR, order_id VARCHAR, review_score VARCHAR,
  review_comment_title VARCHAR, review_comment_message VARCHAR,
  review_creation_date VARCHAR, review_answer_timestamp VARCHAR,
  _source_file VARCHAR, _loaded_at TIMESTAMP_NTZ
);
COPY INTO OLIST.RAW.ORDER_REVIEWS
FROM (SELECT $1,$2,$3,$4,$5,$6,$7, METADATA$FILENAME, CURRENT_TIMESTAMP()
      FROM @OLIST.RAW.OLIST_STAGE/olist_order_reviews_dataset.csv)
ON_ERROR = 'ABORT_STATEMENT';

-- CATEGORY TRANSLATION
CREATE OR REPLACE TABLE OLIST.RAW.PRODUCT_CATEGORY_TRANSLATION (
  product_category_name VARCHAR, product_category_name_english VARCHAR,
  _source_file VARCHAR, _loaded_at TIMESTAMP_NTZ
);
COPY INTO OLIST.RAW.PRODUCT_CATEGORY_TRANSLATION
FROM (SELECT $1,$2, METADATA$FILENAME, CURRENT_TIMESTAMP()
      FROM @OLIST.RAW.OLIST_STAGE/product_category_name_translation.csv)
ON_ERROR = 'ABORT_STATEMENT';