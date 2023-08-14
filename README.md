# Overall
We are going to need 6 VMs with Centos7 on board in the same local subnet:

- Ozone cluster:
  - On VM1 we place OM and SCM.
  - On VM2 we place 1st Datanode.
  - On VM3 we place 2d Datanode.
  - On VM4 we place 3d Datanode.
- Kerberos:
  - On VM5 we place Kerberos, Kerberos will appear on 88 port.
- Spark cluster
  - On VM6 we place Spark on Kubernetes. It will be our client to Ozone.
 

# Prerequisites:

Distribute Ozone tarball and this ozone test to each VM:

```
cd
curl https://dlcdn.apache.org/ozone/1.3.0/ozone-1.3.0.tar.gz -o ozone-1.3.0.tar.gz
tar -xf ozone-1.3.0.tar.gz

cd
yum install git -y
git clone https://github.com/MerelyOneMax1986/ozone-test.git

```

Prepare **/data01** folder with enough space for Ozone.

## Kerberos setup

First, install Docker, for instance:
```
bash docker.install.sh
```
Now deploy Kerberos:
```
cd
cd ozone-1.3.0
docker run -d -P -v $PWD/compose/_keytabs:/etc/security/keytabs --network=host apache/ozone-testkrb5:20210419-1 /usr/sbin/krb5kdc -n
```

## Ozone bare metal setup

Repeat steps for each VM1-VM4:

- Distribute and install Java.
For instance, you can pick the latest Java 11 from the site https://www.openlogic.com/openjdk-downloads?field_java_parent_version_target_id=406&field_operating_system_target_id=426&field_architecture_target_id=391&field_java_package_target_id=396 
in tar.gz format and follow the instructions:

```
sudo -i
mkdir -p ~/jres
cd ~/jres
curl https://builds.openlogic.com/downloadJDK/openlogic-openjdk/11.0.19+7/openlogic-openjdk-11.0.19+7-linux-x64.tar.gz -o openlogic-openjdk-11.0.19+7-linux-x64.tar.gz
tar -xf openlogic-openjdk-11.0.19+7-linux-x64.tar.gz -C ~/jres
ln -s ~/jres/openlogic-openjdk-11.0.19+7-linux-x64 ~/jres/java-11
export JAVA_HOME=~/jres/java-11
printenv | grep JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"
java -version
echo "export JAVA_HOME=~/jres/java-11" > /etc/profile.d/java.sh
```

- Prepare Ozone conf

Look at the example **ozone-site.xml** and replace placeholder **VM1** with an actual address of VM1. Then copy contents of changed file **ozone-site.xml** to **etc/hadoop/ozone-site.xml**.
Look at the example **krb5.conf** file and replace placeholder **VM5** with an actual address of VM5. Then copy contents of changed file **krb5.conf** to **/etc/krb5.conf**.

```
cd
cd ozone-1.3.0
mkdir -p /etc/security/keytabs/
cp compose/_keytabs/*.keytab /etc/security/keytabs/

cd
git clone https://github.com/MerelyOneMax1986/ozone-test.git
cd ozone-test

# !!! First change placeholders and only after that run the commands !!!
# Note: You may use sed for that like:
# sed 's/VM1/XX.XX.XX.XX/g' -i ozone-site.xml
# sed 's/VM5/XX.XX.XX.XX/g' -i krb5.conf

\cp ozone-site.xml ../ozone-1.3.0/etc/hadoop/
\cp core-site.xml ../ozone-1.3.0/etc/hadoop/
\cp krb5.conf /etc

```

Install OM and SCM 

Do steps on VM1:

```
sudo -i
cd
cd ozone-1.3.0 
cd bin/

./ozone scm --init
./ozone --daemon start scm


./ozone om --init
./ozone --daemon start om

```

Install Ozone datanodes

Do steps on VM2-VM4:

```
sudo -i
cd
cd ozone-1.3.0 
cd bin/

./ozone --daemon start datanode
```

Go to VM1 and prepare Ozone initial folder structure:


```
yum install krb5-workstation krb5-libs -y
kinit -kt /etc/security/keytabs/testuser.keytab testuser/scm@EXAMPLE.COM
cd
cd ozone-1.3.0 
cd bin/
./ozone sh volume create /volume1
./ozone sh bucket create /volume1/bucket1
./ozone sh key put /volume1/bucket1/test /etc/hosts
```

Congrats! Looks like Ozone setup is well done.

## Ozone client setup

Go to VM6.

First, create Kubernetes cluster:
```
bash docker.install.sh
bash k8s.init.sh
bash k8s.post.init.sh
bash k8s.check.dns.sh
```

Make OM services accessible to Spark cluster via name.
Look at the example **om-svc.yaml**. Replace placeholder **VM1** with an actual address of VM1.

```
# !!! First change placeholders and only after that run the commands !!!
# Note: You may use sed for that like:
# sed 's/VM1/XX.XX.XX.XX/g' -i om-svc.yaml

kubectl apply -f om-svc.yaml
```

Start your Jupyter server and run Spark session in client mode:

```
docker pull jupyter/pyspark-notebook:spark-3.2.1
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: jupyter
  name: jupyter
spec:
  containers:
  - image: jupyter/pyspark-notebook:spark-3.2.1
    name: jupyter
    command:
    - start-notebook.sh
    args:
    - --ip=0.0.0.0
    - --port=8888
    - --NotebookApp.default_url=/lab
    - --NotebookApp.token=''
    - --NotebookApp.password=''
    imagePullPolicy: Always
    volumeMounts:
    - name: work
      mountPath: /home/jovyan/work
    - name: data
      mountPath: /data
    - name: tmp
      mountPath: /tmp
  volumes:
    - name: work
      emptyDir: {}   
    - name: data
      emptyDir: {}
    - name: tmp
      emptyDir: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
EOF
kubectl wait --for=condition=Ready pod/jupyter
kubectl port-forward pod/jupyter 8888:8888 --address=0.0.0.0
```
Now your Jupyter server is accessble via [VM6 IP address]:8888.

Send test user keytab to your Jupyter server:
```
PYSPARK_POD_NAME=jupyter
cd
cd ozone-1.3.0
kubectl cp ./compose/_keytabs/testuser.keytab $PYSPARK_POD_NAME:/home/jovyan/
```

Replace placeholder **VM5** with an actual address of VM5 and copy contents of changed file **krb5.conf** to **/etc/krb5.conf**
```
cd
git clone https://github.com/MerelyOneMax1986/ozone-test.git
cd ozone-test

# !!! First change placeholders and only after that run the commands !!!
# Note: You may use sed for that like:
# sed 's/VM5/XX.XX.XX.XX/g' -i krb5.conf
PYSPARK_POD_NAME=$(docker ps | grep k8s_jupyter_jupyter_default | awk '{print $1}')
docker cp krb5.conf $PYSPARK_POD_NAME:/etc/
docker cp krb5.conf $PYSPARK_POD_NAME:/usr/local/spark/conf/

docker cp log4j.properties $PYSPARK_POD_NAME:/usr/local/spark/conf/
docker cp HADOOP_CONF_DIR/core-site.xml $PYSPARK_POD_NAME:/usr/local/spark/conf/
docker cp HADOOP_CONF_DIR/hdfs-site.xml $PYSPARK_POD_NAME:/usr/local/spark/conf/
```

Create a Service account for Spark driver to manage the cluster:
```
kubectl create sa spark
kubectl create clusterrolebinding spark-cluster-admin --clusterrole=cluster-admin --serviceaccount=default:spark

# Select name of cluster you want to interact with from above output:
export CLUSTER_NAME="dsml-platform"

# Point to the API server referring the cluster name
APISERVER=$(kubectl config view -o jsonpath="{.clusters[?(@.name==\"$CLUSTER_NAME\")].cluster.server}")

SECRET_NAME=$(kubectl get serviceaccount spark -o jsonpath='{.secrets[0].name}')

# Get the token value
TOKEN=$(kubectl get secret $SECRET_NAME -o jsonpath='{.data.token}' | base64 --decode)

touch spark-cluster-kubeconfig
kubectl config --kubeconfig=spark-cluster-kubeconfig set-cluster $CLUSTER_NAME --server=$APISERVER --insecure-skip-tls-verify=true   
kubectl config --kubeconfig=spark-cluster-kubeconfig set-credentials $CLUSTER_NAME --token=$TOKEN
kubectl config --kubeconfig=spark-cluster-kubeconfig set-context spark --cluster=$CLUSTER_NAME --user=$CLUSTER_NAME
   
cat spark-cluster-kubeconfig
```

Go to JupyterLab terminal and paste the contents of the file **spark-cluster-kubeconfig**:

```
mkdir -p /home/jovyan/.kube/
cat > /home/jovyan/.kube/config
```

Then run Spark cluster on Kubernetes in a cluster mode by issuing in JupyterLab terminal:
```
git clone https://github.com/MerelyOneMax1986/ozone-test.git
cd ozone-test
bash ozone-test.sh
```
Or you can run Spark cluster on Kubernetes in a client mode by running Jupyter notebook **ozone-test_Spark_client_mode.ipynb**


Then go to the Spark cluster and see the logs like:
```
kubectl logs spark-hdfs-16964589e9fdf561-driver -f
```
Notes:

Docker image for Spark worker is fully compatible with Spark v.3.2.1 on Kubernetes.
In the test a pre-built image is used, but you can build it yourself, please follow the script in **spark-worker-ozone/build_spark_worker.sh**.

