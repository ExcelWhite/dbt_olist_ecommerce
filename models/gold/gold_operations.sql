with regional_delivery_performance as (
    select 
        c.customer_region,
        count(distinct o.order_id) as total_orders_delivered,
        {{ calculate_percentage(
            'count(case when o.is_delivered_on_time = true then 1 end)', 
            'count(case when o.is_delivered_on_time is not null then 1 end)'
        ) }} as region_on_time_delivery_rate_percentage,
        round(avg(o.actual_delivery_days), 2) as region_avg_delivery_time_days
    from {{ ref('silver_customer_orders_sequenced') }} c
    join {{ ref('silver_orders_enriched') }} o on c.order_id = o.order_id
    where o.order_status = 'delivered'
      and c.customer_region is not null
    group by 1
),

state_level_slow_deliveries as (
    select 
        c.customer_state,
        round(avg(o.actual_delivery_days), 2) as state_avg_delivery_days,
        case when avg(o.actual_delivery_days) > 20 then true else false end as is_slow_state
    from {{ ref('silver_customer_orders_sequenced') }} c
    join {{ ref('silver_orders_enriched') }} o on c.order_id = o.order_id
    where o.order_status = 'delivered'
    group by 1
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
    group by 1
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
    -- Join slowest category benchmark
    (select product_category_english from slowest_category where rank_seq = 1) as platform_slowest_category_name,
    (select avg_category_delivery_days from slowest_category where rank_seq = 1) as platform_slowest_category_avg_days,
    (
        select concat_ws(', ', collect_list(s.customer_state)) 
        from state_level_slow_deliveries s
        join {{ ref('state_regions') }} sr on s.customer_state = sr.state_code
        where sr.region = r.customer_region
    ) as slow_states_in_this_region
from regional_delivery_performance r
order by r.region_avg_delivery_time_days desc
