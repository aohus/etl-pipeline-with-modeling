SELECT
      cr.countryregioncode
    , cr.name
FROM
    person.countryregion cr
WHERE cr.modifieddate >= '{{ execution_date.strftime('%Y-%m-%d') }}'
  AND cr.modifieddate < '{{ (execution_date + macros.timedelta(days=1)).strftime('%Y-%m-%d') }}';