select
    *
from
    {{ source('source', 'order_payments') }}