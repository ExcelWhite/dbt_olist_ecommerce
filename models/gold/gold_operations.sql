with regional_delivery_performance as (
    select 
        c.customer_region,
        count(distinct o.order_id) as total_orders_delivered,
        -- Wrapped inside MAX/SUM aggregates so Spark SQL evaluates groups correctly without GROUP BY conflicts
        {{ calculate_percentage(
            "sum(case when o.is_delivered_on_time = true then 1 else 0 end)", 
            "sum(case when o.is_delivered_on_time is not null then 1 else 0 end)"
        ) }} as region_on_time_delivery_rate_percentage,
        round(avg(o.actual_delivery_days), 2) as region_avg_delivery_time_days
    from {{ ref('silver_customer_orders_sequenced') }} c
    join {{ ref('silver_orders_enriched') }} o on c.order_id = o.order_id
    where o.order_status = 'delivered'
      and c.customer_region is not null
    group by c.customer_region
),

state_level_slow_deliveries as (
    select 
        c.customer_state,
        round(avg(o.actual_delivery_days), 2) as state_avg_delivery_days
    from {{ ref('silver_customer_orders_sequenced') }} c
    join {{ ref('silver_orders_enriched') }} o on c.order_id = o.order_id
    where o.order_status = 'delivered'
    group by c.customer_state
    having avg(o.actual_delivery_days) > 20
),

category_shipping_delays as (
    select 
        items.product_category_english,
        round(avg(o.actual_delivery_days), 2) as avg_category_delivery_days
    from {{ ref('silver_order_items_details') }} items
    join {{ ref('silver_orders_enriched') }} o on items.order_id = o.order_id
    where o.order_status = 'delivered'
      and items.product_category_english is not null
    group by items.product_category_english
),

slowest_category as (
    select 
        product_category_english,
        avg_category_delivery_days,
        row_number() over (order by avg_category_delivery_days desc) as rank_seq
    from category_shipping_delays
)

select 
    r.customer_region,
    r.total_orders_delivered,
    r.region_on_time_delivery_rate_percentage,
    r.region_avg_delivery_time_days,
    (select product_category_english from slowest_category where rank_seq = 1) as platform_slowest_category_name,
    (select avg_category_delivery_days from slowest_category where rank_seq = 1) as platform_slowest_category_avg_days,
    -- COALESCE handles regions with no slow states, rendering 'No Critical Delays' instead of blank cells
    coalesce(
        (
            select concat_ws(', ', collect_list(s.customer_state)) 
            from state_level_slow_deliveries s
            join {{ ref('state_regions') }} sr on s.customer_state = sr.state_code
            where sr.region = r.customer_region
        ), 
        'No Critical Delays (>20d)'
    ) as slow_states_in_this_region
from regional_delivery_performance r
order by r.region_avg_delivery_time_days desc