with customers as (
    select * from {{ ref('bronze_customers') }}
),
orders as (
    select * from {{ ref('bronze_orders') }}
),
regions as (
    select * from {{ ref('state_regions') }}
)

select 
    c.customer_unique_id,
    c.customer_id,
    c.customer_state,
    r.state_name as customer_state_name,
    r.region as customer_region,
    o.order_id,
    cast(o.order_purchase_timestamp as timestamp) as purchased_at,
    row_number() over (partition by c.customer_unique_id order by cast(o.order_purchase_timestamp as timestamp)) as customer_order_sequence
from customers c
join orders o
on c.customer_id = o.customer_id
join regions r
on c.customer_state = r.state_code
