USE WAREHOUSE ELIO_WH;

-- =====================================================================
-- Q1 (Elio #2): Monthly revenue and order trend
-- Excludes canceled/unavailable orders. Limited to complete months
-- (Jan 2017 to Aug 2018): the dataset has only a handful of orders in
-- late 2016 and Sep 2018, which would give meaningless growth figures.
-- =====================================================================
with monthly as (
    select
        date_trunc('month', purchase_date)                 as month,
        count(distinct order_id)                           as orders,
        sum(price)                                         as revenue,
        round(sum(price) / count(distinct order_id), 2)    as revenue_per_order
    from OLIST.MARTS.FCT_ORDER_ITEMS
    where order_status not in ('canceled', 'unavailable')
      and purchase_date >= '2017-01-01'
      and purchase_date <  '2018-09-01'
    group by 1
)

select
    month,
    orders,
    revenue,
    revenue_per_order,
    round(
        100 * (revenue - lag(revenue) over (order by month))
        / nullif(lag(revenue) over (order by month), 0), 1
    ) as revenue_mom_pct
from monthly
order by month;

-- =====================================================================
-- Q2 (Elio #4): Geographic breakdown by customer state (delivered orders)
-- Customer state is taken from the customer's most recent order (dim_customers).
-- =====================================================================
select
    c.state,
    count(distinct f.order_id)             as orders,
    sum(f.price)                           as revenue,
    round(avg(f.freight_value), 2)         as avg_freight_per_item,
    round(avg(f.delivery_days), 1)         as avg_delivery_days,
    round(100 * avg(f.is_late::int), 1)    as pct_items_late,
    round(avg(f.review_score), 2)          as avg_review_score
from OLIST.MARTS.FCT_ORDER_ITEMS f
join OLIST.MARTS.DIM_CUSTOMERS c
    on c.customer_key = f.customer_key
where f.order_status = 'delivered'
group by c.state
order by revenue desc;


-- =====================================================================
-- Q3 (Elio #5): Stakeholder ask on short notice:
-- "How much do late deliveries hurt our review scores?"
-- Collapsed to order grain first so multi-item orders are not counted twice.
-- days_vs_estimate: positive = days late, negative = days early.
-- =====================================================================
with orders as (
    select
        order_id,
        min(days_vs_estimate) as days_vs_estimate,
        min(review_score)     as review_score
    from OLIST.MARTS.FCT_ORDER_ITEMS
    where order_status = 'delivered'
      and days_vs_estimate is not null
      and review_score is not null
    group by order_id
),

bucketed as (
    select
        review_score,
        case
            when days_vs_estimate <= 0 then '1. On time or early'
            when days_vs_estimate <= 3 then '2. Late 1-3 days'
            when days_vs_estimate <= 7 then '3. Late 4-7 days'
            else                            '4. Late 8+ days'
        end as delivery_bucket
    from orders
)

select
    delivery_bucket,
    count(*)                                              as orders,
    round(avg(review_score), 2)                           as avg_review_score,
    round(100 * avg(iff(review_score <= 2, 1, 0)), 1)     as pct_low_reviews
from bucketed
group by delivery_bucket
order by delivery_bucket;


-- =====================================================================
-- Extra (supports Part B): how many customers ever buy more than once?
-- Uses customer_key (the real person), not the per-order customer_id.
-- =====================================================================
with customer_orders as (
    select
        customer_key,
        count(distinct order_id) as orders
    from OLIST.MARTS.FCT_ORDER_ITEMS
    where order_status not in ('canceled', 'unavailable')
    group by customer_key
)

select
    count(*)                                               as customers,
    count_if(orders > 1)                                   as repeat_customers,
    round(100 * count_if(orders > 1) / count(*), 2)        as repeat_rate_pct
from customer_orders;