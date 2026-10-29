with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select customer_id, purchased_at from {{ ref('stg_orders') }}
),

customer_orders as (
    select
        c.customer_unique_id,
        c.customer_id,
        c.zip_code_prefix,
        c.city,
        c.state,
        o.purchased_at
    from customers c
    left join orders o on o.customer_id = c.customer_id
),

ranked as (
    select
        *,
        min(purchased_at) over (partition by customer_unique_id) as first_order_at,
        max(purchased_at) over (partition by customer_unique_id) as last_order_at,
        row_number() over (
            partition by customer_unique_id
            order by purchased_at desc nulls last, customer_id
        ) as rn
    from customer_orders
)

select
    {{ dbt_utils.generate_surrogate_key(['customer_unique_id']) }} as customer_key,
    customer_unique_id,
    zip_code_prefix,
    city,    -- location as of the customer's most recent order
    state,
    first_order_at,
    last_order_at
from ranked
where rn = 1