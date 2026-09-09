WITH deduplicated_items AS (
SELECT 
*, ROW_NUMBER() OVER (PARTITION BY id ORDER BY updateDate DESC) AS deduplication_rank
FROM

    {{ source('source', 'items') }}

)
SELECT 
    id,
    name,
    category,
    updateDate

FROM
    deduplicated_items
WHERE
    deduplication_rank = 1