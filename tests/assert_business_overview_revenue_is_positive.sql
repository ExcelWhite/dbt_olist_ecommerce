select
    order_month,
    monthly_revenue
from {{ ref('gold_business_overview') }}
where monthly_revenue < 0