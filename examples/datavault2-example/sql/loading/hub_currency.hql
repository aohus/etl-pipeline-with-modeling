INSERT INTO TABLE dv_raw.hub_currency
SELECT DISTINCT
    c.hkey_currency,
    c.record_source,
    c.load_dtm,
    c.currencycode
FROM
    advworks_staging.currency_{{execution_date.strftime('%Y%m%dt%H%M%S')}} c
WHERE
    c.currencycode NOT IN (
        SELECT hub.currencycode FROM dv_raw.hub_currency hub
    )
