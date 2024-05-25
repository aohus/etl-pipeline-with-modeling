INSERT INTO TABLE dv_raw.hub_salesreason
SELECT DISTINCT
    sohsr.hkey_salesreason,
    sohsr.record_source,
    sohsr.load_dtm,
    sohsr.name
FROM
    advworks_staging.salesorderheadersalesreason_{{execution_date.strftime('%Y%m%dt%H%M%S')}} sohsr
WHERE
    sohsr.name NOT IN (
        SELECT hub.name FROM dv_raw.hub_salesreason hub
    )
