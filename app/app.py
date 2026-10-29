import os

import pandas as pd
import snowflake.connector
import streamlit as st

st.set_page_config(page_title="Olist explorer", layout="wide")


@st.cache_resource
def get_conn():
    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        password=os.environ["SNOWFLAKE_PASSWORD"],
        role=os.environ.get("SNOWFLAKE_ROLE", "ACCOUNTADMIN"),
        warehouse="ELIO_WH",
        database="OLIST",
        schema="MARTS",
    )


@st.cache_data(ttl=600)
def run(sql: str) -> pd.DataFrame:
    cur = get_conn().cursor()
    try:
        cur.execute(sql)
        df = pd.DataFrame(cur.fetchall(), columns=[c[0].lower() for c in cur.description])
    finally:
        cur.close()
    for col in df.columns:
        try:
            df[col] = pd.to_numeric(df[col])
        except (ValueError, TypeError):
            pass
    return df


MONTHLY = """
select date_trunc('month', purchase_date) as month,
       count(distinct order_id) as orders,
       sum(price) as revenue
from OLIST.MARTS.FCT_ORDER_ITEMS
where order_status not in ('canceled', 'unavailable')
  and purchase_date >= '2017-01-01' and purchase_date < '2018-09-01'
group by 1
order by 1
"""

STATES = """
select c.state,
       count(distinct f.order_id)          as orders,
       sum(f.price)                        as revenue,
       round(100 * avg(f.is_late::int), 1) as pct_items_late,
       round(avg(f.review_score), 2)       as avg_review_score
from OLIST.MARTS.FCT_ORDER_ITEMS f
join OLIST.MARTS.DIM_CUSTOMERS c on c.customer_key = f.customer_key
where f.order_status = 'delivered'
group by c.state
order by revenue desc
"""

DELIVERY = """
with orders as (
    select order_id,
           min(days_vs_estimate) as days_vs_estimate,
           min(review_score)     as review_score
    from OLIST.MARTS.FCT_ORDER_ITEMS
    where order_status = 'delivered'
      and days_vs_estimate is not null
      and review_score is not null
    group by order_id
)
select case
         when days_vs_estimate <= 0 then '1. On time or early'
         when days_vs_estimate <= 3 then '2. Late 1-3 days'
         when days_vs_estimate <= 7 then '3. Late 4-7 days'
         else '4. Late 8+ days'
       end as delivery_bucket,
       count(*) as orders,
       round(avg(review_score), 2) as avg_review_score
from orders
group by 1
order by 1
"""

REPEAT = """
with c as (
    select customer_key, count(distinct order_id) as orders
    from OLIST.MARTS.FCT_ORDER_ITEMS
    where order_status not in ('canceled', 'unavailable')
    group by customer_key
)
select count(*) as customers,
       count_if(orders > 1) as repeat_customers,
       round(100 * count_if(orders > 1) / count(*), 2) as repeat_rate_pct
from c
"""

st.title("Olist marketplace explorer")
st.caption("Reads the dbt marts in Snowflake (OLIST.MARTS).")

rep = run(REPEAT).iloc[0]
k1, k2, k3 = st.columns(3)
k1.metric("Customers", f"{int(rep['customers']):,}")
k2.metric("Repeat customers", f"{int(rep['repeat_customers']):,}")
k3.metric("Repeat rate", f"{rep['repeat_rate_pct']}%")

tab1, tab2, tab3 = st.tabs(["Monthly revenue", "By state", "Delivery vs reviews"])

with tab1:
    monthly = run(MONTHLY)
    st.line_chart(monthly.set_index("month")["revenue"])
    st.dataframe(monthly, use_container_width=True)

with tab2:
    states = run(STATES)
    st.bar_chart(states.set_index("state")["revenue"])
    st.dataframe(states, use_container_width=True)

with tab3:
    delivery = run(DELIVERY)
    st.bar_chart(delivery.set_index("delivery_bucket")["avg_review_score"])
    st.dataframe(delivery, use_container_width=True)