select
    *
from
    {{ source('source', 'products') }}