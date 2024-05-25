INSERT INTO TABLE dv_raw.hub_shipmethod
SELECT DISTINCT
    sm.hkey_shipmethod,
    sm.record_source,
    sm.load_dtm,
    sm.name
FROM
    advworks_staging.shipmethod_{{execution_date.strftime('%Y%m%dt%H%M%S')}} sm
WHERE
    sm.name NOT IN (
        SELECT hub.name FROM dv_raw.hub_shipmethod hub
    )
