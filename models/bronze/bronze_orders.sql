select
    *
from
    {{ source('source', 'orders') }}