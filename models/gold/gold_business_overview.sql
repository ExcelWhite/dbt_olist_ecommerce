with monthly_metrics as (
    -- 1. Orders placed per month & Active unique monthly sellers
    select
        date_trunc('month', o.purchased_at) as order_month,
        count(distinct o.order_id) as total_orders,
        sum(o.total_order_value) as monthly_revenue,
        count(distinct items.seller_id) as active_sellers_this_month
    from {{ ref('silver_orders_enriched') }} o
    join {{ ref('silver_order_items_details') }} items on o.order_id = items.order_id
    where o.order_status = 'delivered'
    group by 1
),

monthly_with_mom as (
    -- 2. Month-over-month revenue change
    select
        order_month,
        total_orders,
        monthly_revenue,
        active_sellers_this_month,
        lag(monthly_revenue) over (order by order_month) as previous_month_revenue,
        {{ calculate_percentage(
            '(monthly_revenue - lag(monthly_revenue) over (order by order_month))', 
            'lag(monthly_revenue) over (order by order_month)'
        ) }} as mom_revenue_change_percentage
    from monthly_metrics
),

seller_monthly_revenue as (
    -- Calculates total revenue per seller per month
    select 
        date_trunc('month', o.purchased_at) as order_month,
        items.seller_id,
        sum(items.price) as seller_monthly_revenue
    from {{ ref('silver_order_items_details') }} items
    join {{ ref('silver_orders_enriched') }} o on items.order_id = o.order_id
    where o.order_status = 'delivered'
    group by 1, 2
),

ranked_monthly_sellers as (
    -- Ranks sellers within each month to isolate the top earner
    select 
        order_month,
        seller_id as top_seller_id,
        seller_monthly_revenue as top_seller_revenue,
        row_number() over (partition by order_month order by seller_monthly_revenue desc) as rank_seq
    from seller_monthly_revenue
)

select
    left(m.order_month, 7) as order_month,
    m.total_orders,
    round(m.monthly_revenue, 2) as monthly_revenue,
    round(m.mom_revenue_change_percentage, 2) as mom_revenue_change_percentage,
    m.active_sellers_this_month,
    s.top_seller_id as top_seller_id_this_month,
    round(s.top_seller_revenue, 2) as top_seller_revenue_this_month
from monthly_with_mom m
left join ranked_monthly_sellers s 
    on m.order_month = s.order_month 
    and s.rank_seq = 1
order by m.order_month