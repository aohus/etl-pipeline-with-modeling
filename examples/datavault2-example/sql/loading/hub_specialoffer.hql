INSERT INTO TABLE dv_raw.hub_specialoffer
SELECT DISTINCT
    so.hkey_specialoffer,
    so.record_source,
    so.load_dtm,
    so.specialofferid
FROM
    advworks_staging.specialoffer_{{execution_date.strftime('%Y%m%dt%H%M%S')}} so
WHERE
    so.specialofferid NOT IN (
        SELECT hub.specialofferid FROM dv_raw.hub_specialoffer hub
    )
