#!/bin/bash
set -eou pipefail
[[ -n ${DEBUG:-} ]] && set -x

KUBERNETES_VERSION=v1.30
PROJECT_PATH=prerelease:/main

command_exist() {
    command -v $@ > /dev/null 2>&1
}

#Check sudo permission
if [[ $USER != "root" ]]; then
    if ! command_exist sudo; then
        cat <<- EOF
        [ERROR] This script need root privilege to execute.
        However, sudo command is unvailable on this machine !!!
EOF
        exit 1
    fi
fi

# Do install
# Install dependencies
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg software-properties-common

# Disable swapfile
sudo swapoff -a  #Disable all swaps from /proc/swaps
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab #Comment the swap line in /etc/fstab
if [[ $(free -m | awk 'NR==3 {print $2}') != 0 ]]; then
    echo "Cannot disable swapfile. Please check again"
    exit 1
fi

#Enable overlay UFS for container runtime
sudo modprobe overlay
#Enable bridge network traffic for container runtime, enable iptables for 
sudo modprobe br_netfilter
#Enable iptables, ip6tables and package forward for bridge network --> Ensure container can communicate with each other
sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system > /dev/null 2>&1


# Create keyrings folder
sudo mkdir -p -m 755 /etc/apt/keyrings

# Install CRIO
curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/$PROJECT_PATH/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/$PROJECT_PATH/deb/ /" | sudo tee /etc/apt/sources.list.d/cri-o.list
sudo apt-get update && sudo apt-get install -y cri-o
wait
sudo sed -i 's#10.85.0.0#172.24.0.0#g' /etc/cni/net.d/*.conflist
sudo systemctl daemon-reload
sudo systemctl start crio
sudo systemctl enable crio

# Install kubeadm, kubectl and kubelet
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update && sudo apt-get install -y kubelet kubeadm kubectl
wait
sudo apt-mark hold kubelet kubeadm kubectl   #Prevent these packages from being upgraded until they are unheld
kubectl version --client && kubeadm version
sudo systemctl enable kubelet

# Pull image of k8s components from registry
sudo kubeadm config images pull --cri-socket unix:///var/run/crio/crio.sock
sudo sysctl -p > /dev/null 2>&1
