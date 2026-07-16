select
    *
from
    {{ source('source', 'order_items') }}