hdfs namenode &

# Wait for a few seconds to ensure the namenode starts properly
sleep 10

# airflow에서 사용할 저장소 만들고 권한 부여
# Check if /user/cloudera directory exists in HDFS
if hdfs dfs -test -d /user/cloudera; then
  echo "HDFS directory /user/cloudera already exists."
else
  echo "Creating HDFS directory /user/cloudera..."
  hdfs dfs -mkdir -p /user/cloudera
fi

# Check ownership of /user/cloudera directory in HDFS
CURRENT_OWNER=$(hdfs dfs -ls /user | grep cloudera | awk '{print $3}')
if [ "$CURRENT_OWNER" == "airflow" ]; then
  echo "HDFS directory /user/cloudera already owned by airflow."
else
  echo "Setting ownership of HDFS directory /user/cloudera to airflow..."
  hdfs dfs -chown airflow:supergroup /user/cloudera
fi

# Check permissions of /user/cloudera directory in HDFS
CURRENT_PERMISSIONS=$(hdfs dfs -ls /user | grep cloudera | awk '{print $1}')
if [[ "$CURRENT_PERMISSIONS" == "drwxrwxr-x" ]]; then
  echo "HDFS directory /user/cloudera already has permissions 775."
else
  echo "Setting permissions of HDFS directory /user/cloudera to 775..."
  hdfs dfs -chmod -R 775 /user/cloudera
fi

# Check if hive user exists
if id -u hive > /dev/null 2>&1; then
  echo "User hive already exists."
else
  echo "Creating user hive..."
  sudo useradd -m hive
fi

# Check if supergroup group exists
if getent group supergroup > /dev/null 2>&1; then
  echo "Group supergroup already exists."
else
  echo "Creating group supergroup..."
  sudo groupadd supergroup
fi

# Add hive user to supergroup if not already a member
if id -nG hive | grep -qw supergroup; then
  echo "User hive is already a member of supergroup."
else
  echo "Adding user hive to group supergroup..."
  sudo usermod -aG supergroup hive
fi

# Wait indefinitely to keep the container running
tail -f /dev/null