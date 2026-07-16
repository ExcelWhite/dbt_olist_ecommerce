{% macro calculate_percentage(numerator, denominator, precision=2) %}
    round(
        try_divide(
            cast({{ numerator }} as double), 
            cast({{ denominator }} as double)
        ) * 100, 
        {{ precision }}
    )
{% endmacro %}