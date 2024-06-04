#!/bin/bash
set -eou pipefail
[[ -n ${DEBUG:-} ]] && set -x

POD_CIDR=172.24.0.0/16                    #Change here
MASTER_NODE=<IP_ADDRESS>                  #IP of master node that initializes the cluster
KEEPALIVED_VIRTUAL_IP=<KEEPALIVED_SERVER_IP>        #Change here
USER=<SSH_USERNAME>                       #Username for SSH user

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

#Get certificate from control plane
sudo mkdir -p /etc/kubernetes/pki/etcd || true
sudo mv /tmp/ca.crt /etc/kubernetes/pki/ca.crt || true
sudo mv /tmp/ca.key /etc/kubernetes/pki/ca.key || true
sudo mv /tmp/sa.key /etc/kubernetes/pki/sa.key || true
sudo mv /tmp/sa.pub /etc/kubernetes/pki/sa.pub || true
sudo mv /tmp/front-proxy-ca.crt /etc/kubernetes/pki/front-proxy-ca.crt || true
sudo mv /tmp/front-proxy-ca.key /etc/kubernetes/pki/front-proxy-ca.key || true
sudo mv /tmp/etcd-ca.crt /etc/kubernetes/pki/etcd/ca.crt || true
# Skip the next line if you are using external etcd
sudo mv /tmp/etcd-ca.key /etc/kubernetes/pki/etcd/ca.key || true

#Join master to control plane
KUBEADM_TOKEN=$(ssh ${USER}@${MASTER_NODE} "kubeadm token list" | awk 'NR==2 {print $1}')
sudo kubeadm join ${KEEPALIVED_VIRTUAL_IP}:6443 --token ${KUBEADM_TOKEN} --control-plane --discovery-token-unsafe-skip-ca-verification --cri-socket unix:///var/run/crio/crio.sock
mkdir -p ~/.kube || true
sudo cp -i /etc/kubernetes/admin.conf ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
