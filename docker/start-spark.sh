#!/bin/bash

. "/opt/spark/bin/load-spark-env.sh"

if [ "$SPARK_MODE" == "master" ]; then
    export SPARK_MASTER_HOST=$(hostname)
    
    # Start Spark Master
    /opt/spark/bin/spark-class org.apache.spark.deploy.master.Master \
        --ip $SPARK_MASTER_HOST \
        --port $SPARK_MASTER_PORT \
        --webui-port $SPARK_MASTER_WEBUI_PORT &
    
    # Wait for Spark Master to be ready
    sleep 5
    
    # Start Thrift server
    echo "Starting Thrift server..."
    /opt/spark/sbin/start-thriftserver.sh \
        --master spark://$SPARK_MASTER_HOST:$SPARK_MASTER_PORT \
        --hiveconf hive.server2.thrift.port=10000 \
        --hiveconf hive.server2.thrift.bind.host=0.0.0.0 &
    
    # Wait for Thrift server to be ready
    sleep 10
    
    echo "Thrift server should be started. Checking..."
    netstat -tlnp | grep 10000 || echo "Warning: Thrift server may not have started correctly"

elif [ "$SPARK_MODE" == "worker" ]; then
    /opt/spark/bin/spark-class org.apache.spark.deploy.worker.Worker \
        --webui-port $SPARK_WORKER_WEBUI_PORT \
        $SPARK_MASTER_URL
else
    echo "Unknown SPARK_MODE: $SPARK_MODE"
    exit 1
fi

# Keep the container running
tail -f /dev/null