# Data model

## 3NF model of the conformed (staging) layer

```mermaid
erDiagram
    CUSTOMERS ||--o{ ORDERS : places
    ORDERS ||--|{ ORDER_ITEMS : contains
    PRODUCTS ||--o{ ORDER_ITEMS : "sold as"
    PRODUCT_CATEGORIES ||--o{ PRODUCTS : classifies
    ORDERS ||--o{ ORDER_REVIEWS : receives

    CUSTOMERS {
        string customer_id PK "one per order"
        string customer_unique_id "the actual person"
        string zip_code_prefix
        string city
        string state
    }
    ORDERS {
        string order_id PK
        string customer_id FK
        string order_status
        timestamp purchased_at
        timestamp approved_at
        timestamp delivered_to_carrier_at
        timestamp delivered_to_customer_at
        timestamp estimated_delivery_at
    }
    ORDER_ITEMS {
        string order_id PK, FK
        int order_item_number PK
        string product_id FK
        string seller_id "sellers table not loaded"
        timestamp shipping_limit_at
        decimal price
        decimal freight_value
    }
    PRODUCTS {
        string product_id PK
        string category_name_pt FK
        int photos_qty
        decimal weight_g
        decimal length_cm
        decimal height_cm
        decimal width_cm
    }
    PRODUCT_CATEGORIES {
        string category_name_pt PK
        string category_name_en
    }
    ORDER_REVIEWS {
        string review_id PK
        string order_id PK, FK
        int review_score
        string review_comment_message
        timestamp review_created_at
        timestamp review_answered_at
    }
```

## Normalisation reasoning

Each entity holds attributes that depend only on its own key: order facts live in ORDERS, line-level facts in ORDER_ITEMS, product attributes in PRODUCTS, and the Portuguese to English category names are split out into PRODUCT_CATEGORIES so a translation is stored once rather than on every product. The many-to-many relationship between orders and products is resolved by ORDER_ITEMS, an associative table keyed by (order_id, order_item_number). Reviews are one-to-many from orders (547 orders have more than one review), and because review_id alone is not unique in the source, REVIEWS is keyed by (review_id, order_id). I deliberately break 3NF in CUSTOMERS: city and state depend on zip_code_prefix rather than on the key, but no clean zip reference table is loaded, so I keep them on the customer row. Another quirk is that customer_id is generated per order, so the real person is customer_unique_id, which is why the mart dimension is built on that instead.

## Star schema in marts

```mermaid
erDiagram
    DIM_CUSTOMERS ||--o{ FCT_ORDER_ITEMS : customer_key
    DIM_PRODUCTS ||--o{ FCT_ORDER_ITEMS : product_key
```

I normalise in staging so cleaning and deduplication happen once, on entities with clear keys, and denormalise into a star schema in marts because analysts then answer questions with one join to a dimension and no multi-hop joins. The fact table (`fct_order_items`) is at order-item grain, carries the numeric measures (price, freight, delivery days) and a date, and is linked to the dimensions by surrogate key.

## Keys, constraints and duplicates

- **Surrogate keys:** `dbt_utils.generate_surrogate_key` (a hash of the natural key) for `customer_key`, `product_key`, `order_item_key` and `review_key`. Natural keys are kept alongside.
- **Duplicates:** staging models dedupe with `QUALIFY ROW_NUMBER()`, keeping the latest loaded row per natural key.
- **Constraints:** Snowflake does not enforce primary, unique or foreign keys on standard tables, so integrity is enforced by dbt tests (`unique`, `not_null`, `relationships`) on every key. `dbt build` fails if a key is duplicated or a foreign key has no parent.

## Materialisation

| Layer | Schema | Materialisation | Why |
|---|---|---|---|
| Raw | `OLIST.RAW` | Tables (loaded with `COPY INTO`) | Kept as loaded, all VARCHAR plus load metadata |
| Staging | `OLIST.STAGING` | Views | Light cleaning only, cheap to rebuild, always reflects raw |
| Marts | `OLIST.MARTS` | Tables | Queried most, so precomputing joins is faster and cheaper |

Evidence: see `+materialized` and `+schema` in `dbt_project/dbt_project.yml`. With larger data, `fct_order_items` would become incremental (merge on `order_item_key`).
