with order_items as (
    select * from {{ ref('stg_order_items') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select customer_id, customer_unique_id from {{ ref('stg_customers') }}
),

latest_review as (
    select order_id, review_score
    from {{ ref('stg_order_reviews') }}
    qualify row_number() over (
        partition by order_id
        order by review_answered_at desc nulls last, review_created_at desc nulls last, review_key
    ) = 1
)

select
    oi.order_item_key,
    oi.order_id,
    oi.order_item_number,
    {{ dbt_utils.generate_surrogate_key(['c.customer_unique_id']) }} as customer_key,
    {{ dbt_utils.generate_surrogate_key(['oi.product_id']) }}        as product_key,
    oi.seller_id,
    o.order_status,
    o.purchased_at,
    o.purchased_at::date                                              as purchase_date,
    o.delivered_to_customer_at,
    o.estimated_delivery_at,
    oi.price,
    oi.freight_value,
    oi.price + oi.freight_value                                       as item_total_value,
    datediff('day', o.purchased_at::date, o.delivered_to_customer_at::date)       as delivery_days,
    datediff('day', o.estimated_delivery_at::date, o.delivered_to_customer_at::date) as days_vs_estimate,
    o.delivered_to_customer_at::date > o.estimated_delivery_at::date  as is_late,
    lr.review_score
from order_items oi
join orders o         on o.order_id = oi.order_id
join customers c      on c.customer_id = o.customer_id
left join latest_review lr on lr.order_id = oi.order_id