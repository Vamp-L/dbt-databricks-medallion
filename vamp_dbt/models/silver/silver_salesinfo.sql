WITH sales AS 
(
    SELECT
        sales_id,
        product_sk,
        customer_sk,
        {{ multiply('unit_price', 'quantity') }} AS gross_amount,
        payment_method

    FROM 
        {{ ref("bronze_sales")}}
),

products AS
(
    SELECT
        product_sk,
        category

    FROM 
        {{ ref("bronze_product")}}
),

customers AS
(
    SELECT
        customer_sk,
        gender

    FROM 
        {{ ref("bronze_customer")}}
),
joined_query AS (
SELECT 
    sales.sales_id,
    sales.gross_amount,
    sales.payment_method,
    products.category,
    customers.gender

FROM 
    sales
JOIN 
    products ON sales.product_sk = products.product_sk
JOIN 
    customers ON sales.customer_sk = customers.customer_sk
)


SELECT 

    category,
    gender,
    SUM(gross_amount) AS total_sales

FROM 
    joined_query 
GROUP BY 
    category, gender
ORDER BY 
    total_sales DESC