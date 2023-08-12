echo "Check Kubernetes DNS service"

kubectl apply -f dnsutils.yaml

sleep 60

kubectl get pods dnsutils

kubectl exec -i -t dnsutils -- nslookup kubernetes.default
