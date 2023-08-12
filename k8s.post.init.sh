
kubectl apply -f system.coredns.yaml

kubectl apply -f flannel.yaml

# untaint master node, only single node use

kubectl taint nodes --all node-role.kubernetes.io/master=:NoSchedule-

