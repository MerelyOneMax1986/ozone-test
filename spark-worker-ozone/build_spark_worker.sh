DOCKER_HUB=buslovaev
SPARK_VERSION=3.2.1
curl https://archive.apache.org/dist/spark/spark-3.2.1/spark-3.2.1-bin-hadoop3.2.tgz -o spark-$SPARK_VERSION-bin-hadoop3.2.tgz
tar -zxvf spark-$SPARK_VERSION-bin-hadoop3.2.tgz
cd spark-$SPARK_VERSION-bin-hadoop3.2

bin/docker-image-tool.sh -r $DOCKER_HUB/spark -t v3.2.1 -p kubernetes/dockerfiles/spark/bindings/python/Dockerfile build

cd ..

docker build -t $DOCKER_HUB/pyspark-ozone:v3.2.1 .

docker push $DOCKER_HUB/pyspark-ozone:v3.2.1

