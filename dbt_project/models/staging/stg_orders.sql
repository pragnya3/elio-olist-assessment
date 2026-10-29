with source as (
    select * from {{ source('raw', 'orders') }}
),

deduped as (
    select *
    from source
    qualify row_number() over (partition by order_id order by _loaded_at desc) = 1
)

select
    order_id,
    customer_id,
    lower(trim(order_status))                           as order_status,
    try_to_timestamp_ntz(order_purchase_timestamp)      as purchased_at,
    try_to_timestamp_ntz(order_approved_at)             as approved_at,
    try_to_timestamp_ntz(order_delivered_carrier_date)  as delivered_to_carrier_at,
    try_to_timestamp_ntz(order_delivered_customer_date) as delivered_to_customer_at,
    try_to_timestamp_ntz(order_estimated_delivery_date) as estimated_delivery_at,
    _source_file                                        as _source,
    _loaded_at
from deduped