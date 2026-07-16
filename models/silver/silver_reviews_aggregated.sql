select
    order_id,
    avg(review_score) as avg_review_score,
    count(review_id) as total_reviews
from {{ ref('bronze_order_reviews') }}
group by order_id