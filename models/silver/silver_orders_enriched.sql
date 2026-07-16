with orders as (
    select *
    from {{ ref('bronze_orders') }}
),
payments as (
    select 
        order_id,
        sum(payment_value) as total_order_value,
        max(payment_installments) as max_payment_installments
    from {{ ref('bronze_order_payments') }}
    group by order_id
)

select
    o.order_id,
    o.customer_id,
    o.order_status,

    cast(o.order_purchase_timestamp as timestamp) as purchased_at,
    cast(o.order_delivered_customer_date as timestamp) as delivered_at,
    cast(o.order_estimated_delivery_date as timestamp) as estimated_delivery_at,

    p.total_order_value,
    p.max_payment_installments,
    case
        when p.max_payment_installments > 1 then true
        else false
    end as is_installment_payment, -- Comma fixed

    -- Spark SQL datediff uses (end_date, start_date)
    {{ datediff_days('o.order_purchase_timestamp', 'o.order_delivered_customer_date') }} as actual_delivery_days,
    {{ datediff_days('o.order_purchase_timestamp', 'o.order_estimated_delivery_date') }} as estimated_delivery_days,
    {{ datediff_days('o.order_estimated_delivery_date', 'o.order_delivered_customer_date') }} as delivery_delay_days,

    -- Evaluates if delivered on or before the estimated date
    case
        when 
            o.order_status = 'delivered' and 
            {{ datediff_days('o.order_delivered_customer_date', 'o.order_estimated_delivery_date') }} >= 0 then true
        when 
            o.order_status = 'delivered' and 
            {{ datediff_days('o.order_estimated_delivery_date', 'o.order_delivered_customer_date') }} < 0 then false
        else null
    end as is_delivered_on_time
from orders o
left join payments p 
on o.order_id = p.order_id