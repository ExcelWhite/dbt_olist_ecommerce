with customer_purchases_by_state as (
    -- 1. Calculations per state: total unique customers & repeat buyers (those who ordered > 1 time)
    select
        customer_state,
        count(distinct customer_unique_id) as total_customers,
        count(distinct case when customer_order_sequence > 1 then customer_unique_id end) as repeat_customers,
        {{ calculate_percentage(
            'count(distinct case when customer_order_sequence > 1 then customer_unique_id end)', 
            'count(distinct customer_unique_id)'
        ) }} as repeat_buyer_rate_percentage
    from {{ ref('silver_customer_orders_sequenced') }}
    group by 1
),

state_revenue_contribution as (
    -- 2. Calculations per state: Total revenue and % share of total platform revenue
    select 
        c.customer_state,
        round(sum(o.total_order_value), 2) as total_revenue,
        round(
            (sum(o.total_order_value) / sum(sum(o.total_order_value)) over()) * 100, 
            2
        ) as revenue_share_percentage
    from {{ ref('silver_customer_orders_sequenced') }} c
    join {{ ref('silver_orders_enriched') }} o on c.order_id = o.order_id
    group by 1
),

state_payment_structures as (
    -- 3. Calculations per state: Average order value (AOV) for Installments vs. Paid in Full
    select
        c.customer_state,
        round(avg(case when o.is_installment_payment = true then o.total_order_value end), 2) as aov_installments,
        round(avg(case when o.is_installment_payment = false then o.total_order_value end), 2) as aov_paid_in_full
    from {{ ref('silver_customer_orders_sequenced') }} c
    join {{ ref('silver_orders_enriched') }} o on c.order_id = o.order_id
    where o.total_order_value is not null
    group by 1
)

-- Combined output: One clean row per state showing all customer behavioral dimensions dynamically!
select 
    rev.customer_state,
    rev.total_revenue as state_total_revenue,
    rev.revenue_share_percentage as state_revenue_share_percentage,
    
    cust.total_customers as state_total_customers,
    cust.repeat_customers as state_repeat_customers,
    cust.repeat_buyer_rate_percentage as state_repeat_buyer_rate_percentage,
    
    pay.aov_installments as state_aov_installments,
    pay.aov_paid_in_full as state_aov_paid_in_full
from state_revenue_contribution rev
join customer_purchases_by_state cust on rev.customer_state = cust.customer_state
join state_payment_structures pay on rev.customer_state = pay.customer_state
order by rev.total_revenue desc
