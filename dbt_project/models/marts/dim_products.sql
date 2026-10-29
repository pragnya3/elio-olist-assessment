with products as (
    select * from {{ ref('stg_products') }}
),

translation as (
    select * from {{ ref('stg_product_category_translation') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['p.product_id']) }} as product_key,
    p.product_id,
    -- fall back to the Portuguese name if untranslated, 'unknown' if missing
    coalesce(t.category_name_en, p.category_name_pt, 'unknown') as category_name,
    p.photos_qty,
    p.weight_g,
    p.length_cm,
    p.height_cm,
    p.width_cm
from products p
left join translation t on t.category_name_pt = p.category_name_pt