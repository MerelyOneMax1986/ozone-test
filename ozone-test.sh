chown jovyan /home/jovyan/testuser.keytab
chmod 400 /home/jovyan/testuser.keytab

klist -kte /home/jovyan/testuser.keytab
kinit -kt /home/jovyan/testuser.keytab testuser/scm@EXAMPLE.COM
klist
export HADOOP_USER_NAME=testuser
export HADOOP_CONF_DIR=HADOOP_CONF_DIR
export HADOOP_JAAS_DEBUG=true
export HADOOP_OPTS="-Djava.net.preferIPv4Stack=true -Dsun.security.krb5.debug=true -Dsun.security.spnego.debug"

spark-submit \
 --deploy-mode cluster \
 --class org.apache.spark.examples.DFSReadWriteTest \
 --master k8s://https://kubernetes.default\
 --conf spark.executor.instances=1 \
 --conf spark.app.name=spark-hdfs \
 --conf spark.kubernetes.container.image=spark:latest \
 --conf spark.kubernetes.kerberos.krb5.path=/etc/krb5.conf \
 --conf spark.kerberos.keytab=/home/jovyan/testuser.keytab \
 --conf spark.kerberos.principal=testuser/scm@EXAMPLE.COM \
 --conf spark.driver.memory=2G \
 --conf spark.executor.memory=4G \
 --conf spark.kubernetes.kerberos.enabled=true \
 --conf spark.kerberos.access.hadoopFileSystems=ofs://om-0.om.default.svc.realm:9862 \
 --conf spark.kubernetes.container.image.pullPolicy="Always" \
 --conf "spark.driver.extraJavaOptions=-Dlog4j.configuration=file:/opt/spark/conf/log4j.properties" \
 --conf "spark.executor.extraJavaOptions=-Dlog4j.configuration=file:/opt/spark/conf/log4j.properties" \
 --conf spark.executorEnv.HADOOP_JAAS_DEBUG=true \
 --conf spark.kubernetes.context=spark --conf spark.kubernetes.trust.certificates=true --conf spark.kubernetes.namespace=default  --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark  --conf spark.kubernetes.authenticate.serviceAccountName=spark --conf spark.kubernetes.container.image=buslovaev/pyspark-ozone:v3.2.1 --conf spark.kubernetes.file.upload.path='/tmp'  local:///opt/spark/examples/jars/spark-examples_2.12-3.2.1.jar /etc/hosts /user/jovyan

