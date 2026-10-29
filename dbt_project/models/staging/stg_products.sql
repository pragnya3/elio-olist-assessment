with source as (
    select * from {{ source('raw', 'products') }}
),

deduped as (
    select *
    from source
    qualify row_number() over (partition by product_id order by _loaded_at desc) = 1
)

select
    product_id,
    lower(trim(product_category_name))         as category_name_pt,
    try_to_number(product_name_lenght)         as name_length,         -- source typo fixed
    try_to_number(product_description_lenght)  as description_length,  -- source typo fixed
    try_to_number(product_photos_qty)          as photos_qty,
    try_to_decimal(product_weight_g, 10, 2)    as weight_g,
    try_to_decimal(product_length_cm, 10, 2)   as length_cm,
    try_to_decimal(product_height_cm, 10, 2)   as height_cm,
    try_to_decimal(product_width_cm, 10, 2)    as width_cm,
    _source_file                               as _source,
    _loaded_at
from deduped