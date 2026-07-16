with category_ratings as (
    -- 1. Average review score and overall delays per product category
    select 
        items.product_category_english,
        count(distinct items.order_id) as total_category_reviews,
        round(avg(rev.avg_review_score), 2) as avg_category_review_score,
        round(avg(o.delivery_delay_days), 2) as avg_category_delivery_delay_days
    from {{ ref('silver_order_items_details') }} items
    join {{ ref('silver_reviews_aggregated') }} rev on items.order_id = rev.order_id
    join {{ ref('silver_orders_enriched') }} o on items.order_id = o.order_id
    where items.product_category_english is not null
    group by 1
),

delay_by_category_and_exact_rating as (
    -- 2. Calculates the average days delayed for each rating bucket PER product category
    select
        items.product_category_english,
        round(rev.avg_review_score, 0) as rounded_review_score,
        round(avg(o.delivery_delay_days), 2) as avg_days_delayed
    from {{ ref('silver_order_items_details') }} items
    join {{ ref('silver_reviews_aggregated') }} rev on items.order_id = rev.order_id
    join {{ ref('silver_orders_enriched') }} o on items.order_id = o.order_id
    where items.product_category_english is not null
    group by 1, 2
),

one_star_global_benchmark as (
    -- 3. Retaining your global platform benchmark for a static comparison line
    select 
        round(avg(o.delivery_delay_days), 2) as platform_avg_delay_for_one_star
    from {{ ref('silver_orders_enriched') }} o
    join {{ ref('silver_reviews_aggregated') }} rev on o.order_id = rev.order_id
    where round(rev.avg_review_score, 0) = 1.00
)

-- Combined output: Dynamically pulls the category-specific extremes and the global baseline
select 
    cr.product_category_english,
    cr.total_category_reviews,
    cr.avg_category_review_score,
    cr.avg_category_delivery_delay_days,
    
    -- Category-specific delays for 1-star and 5-star reviews
    coalesce(r1.avg_days_delayed, 0.00) as category_avg_delay_days_for_1_star_reviews,
    coalesce(r5.avg_days_delayed, 0.00) as category_avg_delay_days_for_5_star_reviews,
    
    -- Global platform benchmark for 1-star reviews
    (select platform_avg_delay_for_one_star from one_star_global_benchmark) as platform_global_avg_delay_for_one_star
from category_ratings cr
left join delay_by_category_and_exact_rating r1 
    on cr.product_category_english = r1.product_category_english 
    and r1.rounded_review_score = 1
left join delay_by_category_and_exact_rating r5 
    on cr.product_category_english = r5.product_category_english 
    and r5.rounded_review_score = 5
order by cr.avg_category_review_score desc