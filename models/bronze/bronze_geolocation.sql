select
    *
from 
    {{ source('source', 'geolocation') }}