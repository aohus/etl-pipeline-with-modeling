INSERT INTO TABLE dv_raw.link_salesorderreason
SELECT DISTINCT
    sor.hkey_salesorderreason,
    sor.hkey_salesreason,
    sor.hkey_salesorder,
    sor.record_source,
    sor.load_dtm
FROM
           advworks_staging.salesorderheadersalesreason_{{execution_date.strftime('%Y%m%dt%H%M%S')}} sor
WHERE
    NOT EXISTS (
        SELECT 
                l.hkey_salesorderreason
        FROM    dv_raw.link_salesorderreason l
        WHERE 
                l.hkey_salesreason = sor.hkey_salesreason
        AND     l.hkey_salesorder = sor.hkey_salesorder
    )
