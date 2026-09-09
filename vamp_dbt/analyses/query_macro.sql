SELECT 
    {{ multiply('sales_id', 'gross_amount') }} AS total_sales
FROM 
    {{ ref("bronze_sales")}}