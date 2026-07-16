select
    *
from 
    {{ source('source', 'customers') }}