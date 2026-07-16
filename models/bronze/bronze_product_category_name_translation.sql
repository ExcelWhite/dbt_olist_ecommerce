select
    *
from
    {{ source('source', 'product_category_name_translation') }}