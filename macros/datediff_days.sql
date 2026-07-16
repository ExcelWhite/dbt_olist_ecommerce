{% macro datediff_days(start_date, end_date) %}
    datediff(
        cast({{ end_date }} as timestamp), 
        cast({{ start_date }} as timestamp)
    )
{% endmacro %}