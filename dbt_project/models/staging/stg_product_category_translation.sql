with source as (
    select * from {{ source('raw', 'product_category_translation') }}
),

deduped as (
    select *
    from source
    qualify row_number() over (partition by product_category_name order by _loaded_at desc) = 1
)

select
    lower(trim(product_category_name))          as category_name_pt,
    lower(trim(product_category_name_english))  as category_name_en,
    _source_file                                as _source,
    _loaded_at
from deduped