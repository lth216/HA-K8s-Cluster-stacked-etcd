#!/bin/bash
set -eou pipefail
[[ -n ${DEBUG:-} ]] && set -x

POD_CIDR=172.24.0.0/16              #Change here - Worker Node IP ranges from 172.24.0.1 - 172.24.0.254
CALICO_VERSION=v3.28.0
MASTER_NODE=<IP_ADDRESS>            #Change here - IP address that initilizes the cluster
KEEPALIVED_VIRTUAL_IP=<KEEPALIVED_SERVER_IP>           #Change here
MASTER_NODE_2=<IP_ADDRESS>          #Change here - IP address of 2nd master node that joins cluster
MASTER_NODE_3=<IP_ADDRESS>          #Change here - IP address of 3rd master node that joins cluster

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

#Init kubeadm cluster
sudo kubeadm init --control-plane-endpoint=${KEEPALIVED_VIRTUAL_IP}:6443 --apiserver-advertise-address=${MASTER_NODE} --pod-network-cidr ${POD_CIDR} --cri-socket unix:///var/run/crio/crio.sock
mkdir -p ~/.kube
sudo cp -i /etc/kubernetes/admin.conf ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

#Install Calico - advanced CNI plugin for K8s
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml
curl https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/custom-resources.yaml -o /tmp/custom-resources.yaml
sed -i "s#192.168.0.0/16#${POD_CIDR}#g" /tmp/custom-resources.yaml
kubectl create -f /tmp/custom-resources.yaml
kubectl cluster-info

#Share certificates to master nodes
MASTER_NODE_LIST=( "${MASTER_NODE_2}" "${MASTER_NODE_3}" )
for NODE in ${MASTER_NODE_LIST[@]}; do
    sudo scp /etc/kubernetes/pki/ca.crt ${USER}@${NODE}:/tmp/ca.crt
    sudo scp /etc/kubernetes/pki/ca.key ${USER}@${NODE}:/tmp/ca.key
    sudo scp /etc/kubernetes/pki/sa.key ${USER}@${NODE}:/tmp/sa.key
    sudo scp /etc/kubernetes/pki/sa.pub ${USER}@${NODE}:/tmp/sa.pub
    sudo scp /etc/kubernetes/pki/front-proxy-ca.crt ${USER}@${NODE}:/tmp/front-proxy-ca.crt
    sudo scp /etc/kubernetes/pki/front-proxy-ca.key ${USER}@${NODE}:/tmp/front-proxy-ca.key
    sudo scp /etc/kubernetes/pki/etcd/ca.crt ${USER}@${NODE}:/tmp/etcd-ca.crt
    # Skip the next line if you are using external etcd
    sudo scp /etc/kubernetes/pki/etcd/ca.key ${USER}@${NODE}:/tmp/etcd-ca.key
done
