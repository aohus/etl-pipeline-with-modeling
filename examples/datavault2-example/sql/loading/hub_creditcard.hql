INSERT INTO TABLE dv_raw.hub_creditcard
SELECT DISTINCT
    cc.hkey_creditcard,
    cc.record_source,
    cc.load_dtm,
    cc.cardnumber
FROM
    advworks_staging.creditcard_{{execution_date.strftime('%Y%m%dt%H%M%S')}} cc
WHERE
    cc.cardnumber NOT IN (
        SELECT hub.cardnumber FROM dv_raw.hub_creditcard hub
    )
