select
    seller_id,
    seller_on_time_delivery_rate_percentage
from {{ ref('gold_sellers_performance') }}
where seller_on_time_delivery_rate_percentage < 0.00 
   or seller_on_time_delivery_rate_percentage > 100.00