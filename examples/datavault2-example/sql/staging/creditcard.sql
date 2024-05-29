SELECT
      cc.creditcardid
    , cc.cardtype
    , cc.cardnumber
    , cc.expmonth
    , cc.expyear
    , LTRIM(RTRIM(COALESCE(CAST(cc.cardnumber as varchar), ''))) as hkey_creditcard
FROM
    sales.creditcard cc
WHERE cc.modifieddate >= '{{ execution_date.strftime('%Y-%m-%d') }}'
  AND cc.modifieddate < '{{ (execution_date + macros.timedelta(days=1)).strftime('%Y-%m-%d') }}';