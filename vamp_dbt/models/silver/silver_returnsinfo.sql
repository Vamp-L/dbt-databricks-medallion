WITH returned AS 
(
    SELECT
        product_sk,
        return_reason,
        refund_amount   
    FROM 
        {{ ref("bronze_returns")}}      
),

product AS 
(
    SELECT 
        product_sk,
        product_name,
        category
    FROM 
        {{ ref("bronze_product")}}  
),

joined_query AS (
SELECT 
    product.product_name,
    product.category,
    returned.return_reason,
    returned.refund_amount

FROM 
    returned
JOIN 
    product ON returned.product_sk = product.product_sk

)

SELECT 
    product_name,
    category,
    return_reason,
    SUM(refund_amount) AS total_refunds
FROM 
    joined_query
GROUP BY 
    product_name, category, return_reason
ORDER BY
    total_refunds DESC