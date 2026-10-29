with source as (
    select * from {{ source('raw', 'customers') }}
),

deduped as (
    select *
    from source
    qualify row_number() over (partition by customer_id order by _loaded_at desc) = 1
)

select
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix    as zip_code_prefix,  -- kept as text to preserve leading zeros
    lower(trim(customer_city))  as city,
    upper(trim(customer_state)) as state,
    _source_file                as _source,
    _loaded_at
from deduped