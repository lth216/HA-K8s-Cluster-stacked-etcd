#!/bin/bash
set -eou pipefail
[[ -n ${DEBUG:-} ]] && set -x

MASTER_NODE=<IP_ADDRESS>                             #Change here - IP address of master node that initilizes the cluster
KEEPALIVED_VIRTUAL_IP=<KEEPALIVED_SERVER_IP>         #Change here
SSH_USER=<USERNAME>                                  #Change here - username of SSH user

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

#Join Worker Node to Control plane
KUBEADM_TOKEN=$(ssh ${SSH_USER}@${MASTER_NODE} "kubeadm token list" | awk 'NR==2 {print $1}')
sudo kubeadm join ${KEEPALIVED_VIRTUAL_IP}:6443 --token ${KUBEADM_TOKEN} --discovery-token-unsafe-skip-ca-verification --cri-socket unix:///var/run/crio/crio.sock
