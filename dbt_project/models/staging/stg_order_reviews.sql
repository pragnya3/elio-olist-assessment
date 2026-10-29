-- review_id is NOT unique in the source (see ingest/NOTES.md), so the grain here
-- is (review_id, order_id), keeping the latest row if that pair is repeated.
with source as (
    select * from {{ source('raw', 'order_reviews') }}
),

deduped as (
    select *
    from source
    qualify row_number() over (
        partition by review_id, order_id
        order by review_answer_timestamp desc nulls last, _loaded_at desc
    ) = 1
)

select
    {{ dbt_utils.generate_surrogate_key(['review_id', 'order_id']) }} as review_key,
    review_id,
    order_id,
    try_to_number(review_score)                    as review_score,
    review_comment_title,
    review_comment_message,
    try_to_timestamp_ntz(review_creation_date)     as review_created_at,
    try_to_timestamp_ntz(review_answer_timestamp)  as review_answered_at,
    _source_file                                   as _source,
    _loaded_at
from deduped