# Docker와 Hadoop 생태계를 활용한 데이터 엔지니어링 프로젝트

## 개요
Docker를 사용하여 Hadoop 생태계의 구성 요소와 기타 필수 서비스를 컨테이너화하여 강력한 데이터 엔지니어링 환경을 설정하는 방법을 보여줍니다. 설정에는 Hadoop (HDFS, YARN), Apache Hive, PostgreSQL 및 Apache Airflow가 포함되며, 이들 모두가 원활하게 작동하도록 구성되어 있습니다. 

## 목적
1. 하둡 생태계의 구성을 알기쉽게 docker container로 구성하고 Web UI를 통해 모니터리할 수 있는 환경울 구성합니다.
2. Airflow를 통해 PostgreSQL 에서 HDFS로 데이터를 옮기고 모델링하여 저장하는 파이프라인을 구축합니다. 
3. 랄프 킴벌의 starschema와 datavault 방식의 데이터모델링 예시를 보여줍니다. 

## 사용 방법
1. clone repository
```bash
git clone <repository-url>
cd <repository-directory>
```

2. 구성 파일 확인
hadoop_config 파일과 기타 구성 파일(e.g., hive-site.xml, core-site.xml 등)이 지정된 디렉토리에 올바르게 설정되었는지 확인합니다.

3. docker-compose 시작
```bash
docker-compose -f docker-compose-datavault2-simple up -d
```

4. 서비스 액세스:
- Hadoop NameNode UI: http://localhost:9870
- ResourceManager UI: http://localhost:8088
- HIVE UI: http://localhost:10002
- Airflow Web UI: http://localhost:8080


## TODO
- [ ] HIVE data 모니터링 
- [ ] airflow celery worker 버전 
- [ ] use dbt


datavault modeling 참고: https://github.com/gtoonstra/etl-with-airflow