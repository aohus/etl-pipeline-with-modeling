SELECT
      p.businessentityid
    , p.persontype
    , p.namestyle
    , p.title
    , p.firstname
    , p.middlename
    , p.lastname
    , p.suffix
    , p.emailpromotion
    , LTRIM(RTRIM(COALESCE(CAST(p.businessentityid as varchar), ''))) as hkey_person
FROM
    person.person p
WHERE p.modifieddate >= '{{ execution_date.strftime('%Y-%m-%d') }}'
  AND p.modifieddate < '{{ (execution_date + macros.timedelta(days=1)).strftime('%Y-%m-%d') }}';