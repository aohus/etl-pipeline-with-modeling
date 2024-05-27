Data Vault 2
============
이것은 아마도 Apache Airflow에서 ETL을 사용하는 방법에 대한 가장 정교한 예제일 것입니다. 이 실습의 일환으로, Hive 위에 구축된 DataVault를 통해 Google BigQuery에 정보 마트를 구축해 보겠습니다. (따라서 이 예제는 메모리가 조금 더 필요하며 간단한 머신에는 적합하지 않을 수 있습니다). Airflow 데이터베이스가 포함된 포스트그레스 인스턴스와 Microsoft에서 자주 사용하는 어드벤처웍스 데이터베이스의 (포스트그레스 포트)를 위한 또 다른 데이터베이스를 시작하겠습니다.

데이터는 Hive로 준비되고 Hive 쿼리를 실행하여 데이터 볼트 모델을 채우겠습니다. 선택 사항으로, 사용해 보고 싶은 Google 계정이 있는 경우 나중에 연결을 설정하고 이 연습의 마지막 부분으로 데이터 볼트에서 일부 플랫 테이블을 BigQuery로 로드하여 기본적으로 정보 마트가 될 수 있습니다.

참고::
- BigQuery 예제를 보려면 자체 Google 클라우드 프로젝트가 활성화되어 있어야 하며, 최소한 Google 클라우드 저장소 및 bigquery 편집 권한(또는 프로젝트 편집 권한 부여)이 있는 자체 서비스 계정을 설정해야 합니다. 그런 다음 해당 프로젝트의 bigquery에서 "information_mart" 데이터 집합을 만들고 원하는 버킷 이름을 만들어야 합니다. bigquery 연결이 생성된 후 프로젝트 ID를 GCP의 프로젝트 ID로 변경합니다(이는 'default' Google 프로젝트로서 필요함).

About Datavault
---------------

이 예에서는 몇 가지 다른 기술을 사용하고 데이터 볼팅과 관련된 모든 모범 사례를 구현하려고 시도합니다. 최종 정보 마트로 들어가는 데이터의 병렬 순방향 흐름과 중간 처리를 개선하기 위한 수단으로 해시를 사용합니다. 해싱이 모든 상황에서 반드시 직관적인 것은 아니므로 실용적인 설계 결정을 내릴 수 있도록 준비해야 합니다.

Overall flow
------------

이것이 OLTP 시스템에서 (최종적으로) 정보 마트로 데이터를 가져오는 일반적인 흐름입니다. 여기에서 데이터 보관소가 몇 년 전 Ralph Inmon이 설명한 대로 기본적으로 엔터프라이즈 데이터 웨어하우스의 역할을 어떻게 수행하는지 확인할 수 있습니다.

.. image:: img/dataflow.jpeg

총 3개의 DAG가 있습니다. "init"으로 시작하는 DAG 하나는 예제를 부트스트랩하기 위한 것으로, 일반적으로 CI 도구 + 다른 도구를 사용하여 스키마를 유지 관리하고 연결 관리를 다른 방식으로 수행하기 때문에 실제 운영 환경에서는 이 DAG를 볼 수 없습니다. 따라서 이 DAG는 무시하세요.

'adventureworks' DAG는 특정 마일스톤으로 표시되는 다섯 가지 특정 흐름이 발생하는 주요 지점입니다:
* Staging
* Applying staging to hubs
* Applying staging to links
* Applying staging to satellites
* End dating satellites

DAG가 완료되면 데이터 웨어하우스는 새로운 상태가 되며, 예를 들어 스타쉐마 DAG에서와 같이 다운스트림 데이터 제품을 새로 고치도록 요청할 수 있습니다.

Staging flow
------------
스테이징은 소스 시스템에서 데이터를 가져와서 가능한 한 소스 데이터를 그대로 유지한 채 'staging' 영역에 로드하는 프로세스입니다. "항목의 데이터 유형을 문자열에서 날짜/시간으로 변경하는 등 'hard' 비즈니스 규칙을 적용할 수 있지만, 들어오는 데이터 요소를 분할, 결합 또는 기타 방식으로 수정하는 것은 피하고 다음 단계에 맡겨야 합니다. 후자는 "soft" 비즈니스 규칙이라고 하며 일반적으로 데이터 해석과 관련된 변환입니다. 요컨대, 정보가 손실될 수 있는 작업은 피해야 합니다.

스테이징 영역은 일시적인 것이며, 원본 시스템에서 델타 로드가 가능하다고 가정하는 이유는 cdc 솔루션이 마련되어 있기 때문입니다. 적절한 CDC가 없어 델타 로드를 구현할 수 없는 경우에는 영구 스테이징 영역(PSA)을 설정하여 거기에서 델타 로드를 생성하고 삭제를 식별할 수 있도록 해야 합니다. 후자와 CDC 솔루션 모두 삭제를 감지할 수 있어야 합니다.

adventureworks 데이터 세트의 모든 테이블에 대한 준비 방식은 다음과 같습니다:

1. 준비 테이블을 지웁니다(truncate or drop). Hive의 경우, 마지막에 날짜 및 시간 태그가 있는 임시 테이블을 사용합니다. 즉, 각 특정 준비 테이블은 현재 데이터 로드의 데이터만 참조할 수 있습니다.
2. (optional) 인덱스를 비활성화합니다. Hive를 사용하므로 이 옵션은 관련이 없으며 인덱스가 설정되지 않습니다.
3. 소스데이터를 순서대로 Bulk Read. 이 예에서는 소스 데이터에 유용한 변경 날짜/시간이 없기 때문에 전체 소스 시스템에서 '모든 것'을 일괄 읽습니다. 실제 애플리케이션에서는 CDC 시스템에서 설정하는 "updated_dtm" 필드를 통해 데이터를 분할합니다.
4. 시스템 값 계산 및 적용: 
   * Load date
   * Record source
   * A sequence number, 현재 배치에서 레코드 순서를 정의하는 시퀀스 번호입니다.
   * Hash for all business keys in a record. 현재 테이블의 레코드일 뿐만 아니라 해당 테이블의 모든 외래 키에 대한 비즈니스 키이기도 합니다. 이것이 중요한 이유는 소스 시스템에 있을 수 있는 모든 대리 시퀀스와 기본 키가 해당 테이블의 비즈니스 키가 아니라면 데이터 웨어하우스에서 아무런 의미가 없어야 하기 때문입니다. 이것이 바로 원시 데이터 볼트에 로드하기 전에 스테이징 영역에 해시를 적용하도록 하는 이유입니다.
   * (optionally) 소스 데이터의 모든 또는 특정 속성에서 컴파일된 해시 차이로 변경 비교를 수행하여 중복을 식별하는 데 사용되므로 레코드를 두 번 로드하지 않습니다. a hash diff compiled from all or certain attributes in the source data that is used to perform change comparisons to identify duplicates, so we don't load records twice.
5. 실제 중복 제거
6. staging table로 insert records
7. (optional) rebuild indexes. 현재 설정과는 관련 없습니ㅏㄷ.

위의 작업을 감안할 때, 수집해야 하는 각 소스 테이블에 매우 일반적인 패턴을 적용할 수 있어야 한다는 것을 알 수 있습니다. 일반적인 전략은 준비 영역에서 현재 날짜 파티션에 대한 모든 관심 레코드가 로드된다는 것입니다. 이러한 레코드에서 레코드에는 최소한 해시 키가 할당되고(대리 기본 키로만 확인되더라도) 모든 외래 키는 다른 테이블에 대한 내부 조인을 생성하여 거기에서 비즈니스 키에 대한 해시 키를 생성할 수 있습니다. 외래 키는 결국 어떤 종류의 링크로 변환될 것이고 해시 키를 준비해 두면 다음 단계도 병렬화할 수 있기 때문입니다. 사실, 나중에 해시를 확인하는 것은 잘못된 것 같습니다. 이러한 조회는 각 테이블에 대한 추가 조인 때문에 소스 시스템에 더 큰 영향을 미칠 수 있지만, 이러한 조회는 '어딘가에서' 이루어져야 하고 소스 시스템이 대리 키가 관련된 곳이라고 생각하기 때문에 거기서 해결해야 합니다.

현재 구현에서는 데이터베이스 엔진이 선택한 해시 알고리즘을 구현하지 않더라도 해싱이 가능하다는 것을 보여주기 위해 파이썬 코드를 사용하여 해싱을 적용하고 있습니다.

참고::
- Adventureworks 데이터베이스에는 몇 가지 심각한 설계 결함이 있으며 데이터 볼트에 매우 중요한 유용한 '자연스러운' 비즈니스 키가 많이 노출되어 있지 않습니다. 비즈니스에는 데이터에 대해 많이 이야기하는 사람들이 있기 때문에 사람들이 실제로 사용하는 실제 데이터베이스 설정에서 훨씬 더 많은 참조, 식별자 및 자연스러운 비즈니스 키를 찾아야 합니다. 주요 스테이징 설정은 'sql' 폴더에 있는 SQL 파일을 참조하는 'adventureworks*.py' 파일에서 이루어집니다. SQL에서는 해당 단계에서 자연스러운 비즈니스 키의 구성을 볼 수 있습니다. 파이썬 연산자는 생성된 문자열을 선택하고 해시 함수를 사용하여 이를 해시로 변환합니다. 레코드별로 이 작업을 수행하는 이유는 소스 데이터베이스 시스템에 반드시 이 작업을 수행하는 데 적합한 기능이 있는 것은 아니기 때문입니다.

스테이징 영역에서 비즈니스 키를 "pre-hashing"하는 것에 대해 중요한 언급이 있습니다. 즉, 무엇을 어떻게 해시할지에 대한 결정은 스테이징 영역에서 이루어지며, 이러한 설계 결정이 작용할 수 있는 다운스트림에서 추가적인 문제가 발생할 수 있습니다. 목표가 방법론을 따르는 것이기 때문에, 저희는 그 방법론에 따라 진행하면서 그 결과를 지켜보고 있습니다. 이 방법이 마음에 들지 않는다면 모든 스테이징 데이터가 보존되므로 나중에 전체 DV를 다시 로드할 수 있는 PSA를 설정하는 방법을 고려해 보세요.

또 다른 중요한 참고 사항: 하이브 스테이징 테이블의 모양을 지정하지 않는다는 점에 주목하세요. 우리는 단순히 하이브 테이블에서 보고자 하는 내용을 지정할 뿐입니다. Hive는 '읽기 시 스키마'이기 때문에 무효화도 적용할 수 없으므로 구조화된 대상 스키마를 설정할 이유가 없습니다(어차피 아무것도 적용할 수 없으므로).


흐름을 좀 더 자세히 살펴보겠습니다:

```python
args = {
    ....
    # We want to maintain chronological order when loading the datavault
    'depends_on_past': True
}
...

# specify the purpose for each dag
RECORD_SOURCE = 'adventureworks.sales'

# Use a dummy operator as a "knot" to synchronize staging loads
staging_done = DummyOperator(
    task_id='staging_done',
    dag=dag)

# A function helps to generalize the parameters,
# so we can just write 2-3 lines of code to get a 
# table staged into our datavault
def create_staging_operator(sql, hive_table, record_source=RECORD_SOURCE):
    t1 = StagePostgresToHiveOperator(
        # The SQL running on postgres
        sql=sql,
        # Create and recreate a hive table with the <name>_yyyymmddthhmmss pattern
        hive_table=hive_table + '_{{execution_date.strftime('%Y%m%dt%H%M%S')}}',
        postgres_conn_id='adventureworks',
        hive_cli_conn_id='hive_advworks_staging',
        # Create a destination table, drop and recreate it every run.
        # Because of the pattern above, we don't need truncates.
        create=True,
        recreate=True,
        record_source=record_source,
        # Specifying the "load_dtm" for this run
        load_dtm='{{execution_date}}',
        # A generalized name
        task_id='stg_{0}'.format(hive_table),
        dag=dag)

    # Putting it in the flow...
    t1 >> staging_done
    return t1

# Example of the effort of staging a new table
create_staging_operator(
    sql='staging/salesorderheader.sql',
    hive_table='salesorderheader')
```

Important design principles to focus on:

- 각 스테이징 테이블은 에어플로우의 처리 실행에 연결되며 고유한 YYYYMMDDTHHMMSS 파티션으로 표시됩니다. 시간 구조를 포함하는 이유는 미리 생각하고 하루에 한 번 이상 데이터 웨어하우스에서 데이터를 더 자주 수집하기 위해서입니다. 이런 식으로 데이터를 별도로 스테이징하기 때문에, 테이블 이름을 올바르게 지정하는 것 외에는 동일한 테이블에서 여러 스테이징 주기를 걱정할 필요가 없고 load_dtm으로 필터링할 필요가 없습니다. 이렇게 하면 어떤 이유로 아직 DV에 데이터를 로드할 수 없는 경우에도 데이터를 계속 스테이징 상태로 로드할 수 있습니다.
- 시간 순서대로 데이터를 데이터볼트에 강제로 로드하기 위해 "depends_on_past"를 True로 설정합니다. 데이터를 스테이징하는 것은 중요한 단계는 아니지만, 각 하위 파이프라인에는 데이터볼트 로드를 위한 연산자도 포함되어 있으므로 기본적으로 전체 dag는 동일한 원리로 설정됩니다.
- 모든 것이 로드되면 임시 준비 테이블을 삭제하거나 파티션된 PSA 테이블로 복사할 수 있습니다.
- 새 테이블은 쿼리와 3줄의 코드를 작성하여 추가할 수 있으며, 이는 이 프로세스를 위한 훌륭한 일반화처럼 보입니다. 템플릿을 설정하고 입력 테이블에서 필요한 테이블을 생성하면 이 프로세스를 더욱 쉽게 수행할 수 있습니다.
- 앞의 요점 때문에 전체 테이블 스테이징 프로세스는 매우 일반적이고 예측 가능합니다.
- 데이터 볼트 설계에서 예상할 수 있는 세 가지 병렬 처리 단계가 있습니다.

Data vault loading flow
-----------------------

이제 데이터가 준비되었으므로 준비된 데이터를 데이터볼트에 로드할 차례입니다. 이를 위해 데이터베이스의 각 스키마마다 하나씩 있는 "adventureworks*" dags를 사용합니다. 다음은 이 전략을 보여주는 다이어그램입니다:

.. image:: img/loading_strategy.jpg

이 과정에서 중요한 디자인 결정이 내려졌습니다:

*모든 외래 키에 대한 비즈니스 키 해시를 얻는 것은 어려운 일이며, 저는 INNER JOIN을 사용하여 소스 데이터베이스에서 모든 해시를 생성하기로 선택했습니다. 그 이유는 다른 부하가 없고 구동 테이블의 하위 선택에 대한 데이터 쿼리 및 조인을 위한 최적화가 잘 되어 있는 CDC 슬레이브 데이터베이스 시스템을 가정했기 때문입니다*

이 문제를 해결할 수 있는 세 가지 가능성이 있다고 생각합니다:

- 소스 시스템에서 모든 기본+외래 키에 대한 해시를 생성합니다(이 구현에서와 같이). 그 이유는 RDBMS에서 자주 사용되는 대리 시퀀스 키는 해당 RDBMS의 컨텍스트 내에서만 의미가 있어야 하므로 비즈니스 키를 가능한 한 빨리 비즈니스 엔티티에 적용하는 것이 중요하기 때문입니다.
- 우연히 발견한 비즈니스 키에 대한 해시를 생성한 다음, 데이터 볼트에서 보다 정교한 조인(경우에 따라 새틀라이트 조인까지 포함)을 사용하세요.
- 스테이징 영역에서 각 소스 시스템에 대한 캐시/조회 테이블을 만들어 데이터 웨어하우스의 필수적인 부분이 되게 하세요. 이 아이디어는 소스 시스템에서 대리 키를 분리하고 소스 시스템에 큰 부하를 추가하지 않고도 이를 해시로 변환하는 것입니다. 그 근거는 데이터 웨어하우스가 작동하려면 해시 키가 필요하지만, 소스 시스템에서 DWH가 요청하는 모든 데이터를 제공했기 때문입니다. DWH 자체에서 필요한 해시 키를 캐싱하고 전달할 책임이 있어야 합니다.


This is a block template of code significant for the loading part:

```python
hubs_done = DummyOperator(
    task_id='hubs_done',
    dag=dag)
links_done = DummyOperator(
    task_id='links_done',
    dag=dag)
sats_done =  DummyOperator(
    task_id='sats_done',
    dag=dag)

def create_hub_operator(hql, hive_table):
    t1 = HiveOperator(
        hql=hql,
        hive_cli_conn_id='hive_datavault_raw',
        schema='dv_raw',
        task_id=hive_table,
        dag=dag)

    staging_done >> t1
    t1 >> hubs_done
    return t1

def create_link_operator(hql, hive_table):
    t1 = HiveOperator(
        hql=hql,
        hive_cli_conn_id='hive_datavault_raw',
        schema='dv_raw',
        task_id=hive_table,
        dag=dag)

# hubs
create_hub_operator('loading/hub_salesorder.hql', 'hub_salesorder')
....

# links
create_link_operator('loading/link_salesorderdetail.hql', 'link_salesorderdetail')
....
```

Each operator links to the dummy, which gives us the synchronization points. 
Because links may have dependencies outside each functional area (determined by the schema)
some further synchronization is required there.

The loading code follows the same principles as the Data Vault 2.0 default stanzas:

Loading a hub is concerned about creating an 'anchor' around which elements referring to a business
entity resolve. Notice the absence of "record_source" check, so whichever system first sees this 
business key will win the record inserted here.:

```SQL
INSERT INTO TABLE dv_raw.hub_product
SELECT DISTINCT
    p.hkey_product,
    p.record_source,
    p.load_dtm,
    p.productnumber
FROM
    advworks_staging.product_{{execution_date.strftime('%Y%m%dt%H%M%S')}} p
WHERE
    p.productnumber NOT IN (
        SELECT hub.productnumber FROM dv_raw.hub_product hub
    )
```

Loading a link is basically tying some hubs together. Any details related to the characteristics of the relationship are kept in a satellite table tied to the link.

```SQL
INSERT INTO TABLE dv_raw.link_salesorderdetail
SELECT DISTINCT
    sod.hkey_salesorderdetail,
    sod.hkey_salesorder,
    sod.hkey_specialoffer,
    sod.hkey_product,
    sod.record_source,
    sod.load_dtm,
    sod.salesorderdetailid
FROM
            advworks_staging.salesorderdetail_{{execution_date.strftime('%Y%m%dt%H%M%S')}} sod
WHERE
    NOT EXISTS (
        SELECT 
                l.hkey_salesorderdetail
        FROM    dv_raw.link_salesorderdetail l
        WHERE 
                l.hkey_salesorder = sod.hkey_salesorder
        AND     l.hkey_specialoffer = sod.hkey_specialoffer
        AND     l.hkey_product = sod.hkey_product
    )
```
Loading satellite is the point where chronological ordering becomes truly important. If we don't get the load cycles in chronological order for hubs and links then the "load_dtm" for them will be wrong, but functionally the data vault should keep operating. Why is this only relevant for satellites?  Because hubs and links do not have 'rate-of-change'. The links document relationships, but these do not change over time, except for their supposed effectivity. Hubs document the presence of business keys, but these do not change over time, except for their supposed effectivity. Only satellites have a rate-of-change associated with them, which is why they have start and end dates. It is possible that a business key or relation gets deleted in the source system. In our our datavault we'd like to maintain the data there (we never delete except for corruption / resolving incidents). The way how that is done is through "effectivity" tables, which are start/end dates in a table connected to the hub or link that record over which time that hub or link should be active.

For satellites, the chronological ordering determines the version of the entity at a specific time, so it affects what the most current version would look like now. This is why they have to be loaded in chronological order, because if they were not, the last active record would be different and the active periods would probably look skewed. Another objective for loading it in chronological order is to eliminate true duplicates; if the records come in fast and do not have a chronological order than either true duplicates are not always detected or un-true duplicates are detected and records get eliminated.

Splitting a satellite is a common practice to record data that has different rates of change. For example, if a table has 40 columns as 20 columns change rapidly and 20 more slowly, then if we were to keep everything in the same table, we'd accumulate data twice as fast. By splitting it into 2 separate tables we can keep the detailed changes to a minimum. This is the typical stanza for loading a satellite. Pay attention to how in Hive you can't specify destination columns. If you keep staging data in the same table you'd also have an additional WHERE clause that specifies `load_dtm = xxxxx`.

.. code-block:: SQL

    INSERT INTO TABLE dv_raw.sat_salesorderdetail
    SELECT DISTINCT
          so.hkey_salesorderdetail
        , so.load_dtm
        , NULL
        , so.record_source
        , so.carriertrackingnumber
        , so.orderqty
        , so.unitprice
        , so.unitpricediscount
    FROM
                    advworks_staging.salesorderdetail_{{execution_date.strftime('%Y%m%dt%H%M%S')}} so
    LEFT OUTER JOIN dv_raw.sat_salesorderdetail sat ON (
                    sat.hkey_salesorderdetail = so.hkey_salesorderdetail
                AND sat.load_end_dtm IS NULL)
    WHERE
       COALESCE(so.carriertrackingnumber, '') != COALESCE(sat.carriertrackingnumber, '')
    OR COALESCE(so.orderqty, '') != COALESCE(sat.orderqty, '')
    OR COALESCE(so.unitprice, '') != COALESCE(sat.unitprice, '')
    OR COALESCE(so.unitpricediscount, '') != COALESCE(sat.unitpricediscount, '')

End dating
----------

The hubs and links do not contain start and end dates, because they record relationships, even relationships that were valid at some point in time. If you need to cater for employees joining, leaving and joining again for example, you should use an "effectivity" table connected to the link or hub to cater for that.

The satellites do have validity dates, because you can have different versions of those. The way how you apply those can differ a bit, because you may not always have the required source data if you don't have a change data capture setup. Then you'd only ever
see the last version of a record or the records that the source system decided to maintain as history. The date you'd apply as start/end date could then differ.

It's always very important to maintain the "load_dtm" and "load_end_dtm" separately as well, because you'd use that to identify
data from batches that may have failed for example. If you maintain it, you can always remove data for an entire batch and reload it into the data vault.

The process of end dating is to apply end dates to records in the satellite tables. For Hive, because we can't run updates, we'll copy the data to a temp table and then copy it back to the original. We can use windowing functions like LAG/LEAD and PARTITION statements, so we use that to look ahead by one row for each partition to look up the next start date and apply that for the end date.

When a record for a partition has a NULL end_dtm, then it means it's the active record. You could choose to explicitly indicate the active record too.

Star Schema
-----------

The star schema is built with the help of some multi-join queries. The dimensions are built up first and then
the fact information is built on top of the dimensions. You don't need to build the dimensions with one single query,
it's obviously permissible to run a multi-stage pipeline to get the dimensions built.

Here's a [good article](https://towardsdatascience.com/a-beginners-guide-to-data-engineering-part-ii-47c4e7cbda71) on how Hive is used with dimensional data:

The dimensions in this example use the original hash key as main key for the dimensional entity and in the case of slowly changing dimensions (where dates are applicable and important), it tags the start date on top of the hash key of the entity to derive a new dimensional key.

The fact is built on top of one of the measures of interest. Usually, you'll find that these are link tables, because they often
link the entities in a context together. For example, the orderlineitem is a link table, because it links the order data with
sold product data, applied discounts and some other data depending on the business.

The fact table can rapidly become complex if there is a lot of data to link together. Similar to building the dimension models, consider splitting up the complex queries by using temp tables that are joined together afterwards to compose the full picture.

The example shows how to generate a star schema from scratch without applying incremental changes. If your data vault grows
a bit large than regenerating it from scratch will be very costly to do, if not impossible within the given timeframe. Refer to the article in this section for a method that shows how to copy the dimension of the day before and union that to new records in the dimension.

Future considerations
---------------------

What is not shown in this example and which should be considered in real world scenarios:

* Dealing with "delete" records in data sources. You'd typically apply these as 'effectivity' records on hubs and links.
* Dealing with "record order" correctly. The current post-update scripts that do the end-dating assume there is one record per entity in the time interval, but there may be multiple. Make sure that the end dating script applies the end date to the records in the correct order and ensure the most recent record comes out on top with "NULL" applied in the end_dtm.
* Dealing with (potentially) large output (larger than 2GB). At the moment the worker reads in all the data in memory and then copies it again into a JSON structure. 

There are ways to output data to multiple files in a single statement using a "named pipe" on the worker itself. The named pipe serves the function as a splitter. You'd then start a "linux split" command on the worker reading from the named pipe (which looks just like a file, except it cannot seek in the stream). The split command takes the input and splits the data into separate files of a particular maximum size or maximum number of lines. If you do this to a particular temporary directory of interest, you can then upload the files to GCP from that directory in one easy operation, either through the gsutil command or an operator.

.. code-block:: python

    with tempfile.NamedTemporaryDir(prefix='export_' as tmp_dir:
        fifo_path = os.path.join(tmp_dir.name, 'fifopipe')
        os.mkfifo(fifo_path)
        p = subprocess.Popen(['split','--numlines','100000','-',prefix])
        hiveHook.to_csv(<query>, fifo_path, ...)
        p.communicate()
        os.remove(fifo_path)
        datafiles = [f for f in listdir(tmp_dir) if isfile(join(tmp_dir, f)) 
                     and f.startswith(prefix)]
        for data_file in datafiles:
            remote_name = '{0}.csv'.format(data_file)
            gcp_hook.upload(self.bucket, remote_name, data_file)

Or use a call to gsutil to perform a data upload in parallel.

Data issues
-----------

The adventure works database isn't the best designed OLTP database ever. Throughout querying and working with the data I found the following data issues:

* Address missed a row in the destination data. "Everett" has two records in address and the only difference is the stateprovinceid. Either the boundaries shifted or there was a correction made in the data.
* There are some 700 personid's missing for "customer" in the source data. Looks like it malfunctioned and never got fixed?
* 209 products do not have sub categories, so I allowed that to be NULLable.
* There can be multiple sales reasons for a salesorder (as per the design). There is a hard business rule when constructing the dim_salesorder which picks the first sales reason by sales reason name ordered ascending to apply to the dimension.
* Because of an incomplete business key in address multiple records get created in the dim_address table (4 in total). This table gets cartesian joined again to populate the fact, which leads to a total of 16 records too many for a specific salesorder ('16B735DD67E11B7F9028EF9B4571CF25D1017CF1')
* Data has not been checked for consistency, correctness and bugs may exist anywhere in the code.
