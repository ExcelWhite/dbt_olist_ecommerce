with seller_order_metrics as (
    -- Gathers primary volume, shipping speed, and rating aggregates per seller
    select
        items.seller_id,
        items.seller_state,
        count(distinct items.order_id) as total_orders_fulfilled,
        round(sum(items.price), 2) as total_seller_revenue,
        round(avg(rev.avg_review_score), 2) as seller_average_review_score,
        round(
            try_divide(
                count(case when o.is_delivered_on_time = true then 1 end),
                count(case when o.is_delivered_on_time is not null then 1 end)
            ) * 100, 
            2
        ) as seller_on_time_delivery_rate_percentage
    from {{ ref('silver_order_items_details') }} items
    join {{ ref('silver_orders_enriched') }} o on items.order_id = o.order_id
    left join {{ ref('silver_reviews_aggregated') }} rev on items.order_id = rev.order_id
    group by 1, 2
),

quartile_assignments as (
    -- Splits sellers into quartiles to identify high-revenue and low-rating performers
    select
        *,
        ntile(4) over (order by total_seller_revenue asc) as revenue_quartile,
        ntile(4) over (order by seller_average_review_score asc) as review_quartile
    from seller_order_metrics
)

-- Combined output: One row per seller with explicit business segment flags
select
    seller_id,
    seller_state,
    total_orders_fulfilled,
    total_seller_revenue,
    seller_average_review_score,
    seller_on_time_delivery_rate_percentage,
    
    -- 1. Sellers who fulfilled more than 100 orders
    case 
        when total_orders_fulfilled > 100 then true 
        else false 
    end as is_high_volume_seller,
    
    -- 2. Sellers with an on-time delivery rate below 80%
    case 
        when seller_on_time_delivery_rate_percentage < 80.00 then true 
        else false 
    end as is_unreliable_shipper,
    
    -- 3. High-revenue, low-rating sellers (The Platform's Risk Segment)
    case 
        when revenue_quartile = 4 and review_quartile = 1 then true 
        else false 
    end as is_high_revenue_low_rating_risk
from quartile_assignments
order by total_seller_revenue desc