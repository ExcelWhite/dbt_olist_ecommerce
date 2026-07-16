with items as (
    select * from {{ ref('bronze_order_items') }}
),
products as (
    select * from {{ ref('bronze_products') }}
),
translations as (
    select * from {{ ref('bronze_product_category_name_translation') }}
),
sellers as (
    select * from {{ ref('bronze_sellers') }}
)

select
    i.order_id,
    i.order_item_id,
    i.product_id,
    i.seller_id,
    i.price,
    i.freight_value,
    i.shipping_limit_date,
    s.seller_state,
    coalesce(t.product_category_name_english, p.product_category_name) as product_category_english
from items i
left join products p on i.product_id = p.product_id
left join translations t on p.product_category_name = t.product_category_name
left join sellers s on i.seller_id = s.seller_id