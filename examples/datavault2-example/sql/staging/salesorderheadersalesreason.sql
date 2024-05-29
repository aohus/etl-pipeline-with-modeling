SELECT
      sohsr.salesorderid
    , sr.name
    , LTRIM(RTRIM(COALESCE(CAST(sohsr.salesorderid as varchar), ''))) as hkey_salesorder
    , LTRIM(RTRIM(COALESCE(CAST(sr.name as varchar), ''))) as hkey_salesreason
    , CONCAT(
          LTRIM(RTRIM(COALESCE(CAST(sohsr.salesorderid as varchar), ''))), ';'
        , LTRIM(RTRIM(COALESCE(CAST(sr.name as varchar), '')))
      ) as hkey_salesorderreason
FROM
            sales.salesorderheadersalesreason sohsr
INNER JOIN  sales.salesreason sr ON sohsr.salesreasonid = sr.salesreasonid
WHERE sohsr.modifieddate >= '{{ execution_date.strftime('%Y-%m-%d') }}'
  AND sohsr.modifieddate < '{{ (execution_date + macros.timedelta(days=1)).strftime('%Y-%m-%d') }}';