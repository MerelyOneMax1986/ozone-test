echo "Old cluster deinstalling..."
kubeadm reset -f
sudo rm -rf /etc/cni/net.d
sudo ip link delete cni0
sudo ip link delete flannel.1
#sudo systemctl restart network
sudo rm -f $HOME/.kube/config

echo "Give your machine stable DNS name at /etc/hosts"
echo " Like "
echo "10.0.2.15 ozone"

echo "Premanently disable swap"
echo "Like"
echo "vi /etc/fstab "
echo " # ...swap"

echo "We currently disable swap temporarily"

sudo swapoff -a
systemctl disable firewalld
systemctl stop firewalld

# network prerequisites

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system
echo "Verify that the br_netfilter, overlay modules are loaded by running below instructions:"

lsmod | grep br_netfilter
lsmod | grep overlay

echo "Verify that the net.bridge.bridge-nf-call-iptables, net.bridge.bridge-nf-call-ip6tables, net.ipv4.ip_forward system variables are set to 1 in your sysctl config by running below instruction:"

sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward

# default flannel network
sudo kubeadm init --config kubeadm.config.yaml --v=5

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

yum install bash-completion -y
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc

exec bash

