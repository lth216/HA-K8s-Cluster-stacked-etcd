#!/bin/bash
set -eou pipefail
[[ -n ${DEBUG:-} ]] && set -x

MASTER_NODE_1=<IP_ADDRESS>    #Change here for 1st master node
MASTER_NODE_2=<IP_ADDRESS>    #Change here for 2nd master node
MASTER_NODE_3=<IP_ADDRESS>    #Change here for 3rd master node
STAT_USR_AUTH=<username>    #Change here for basis auth when accessing stat page
STAT_PSW_AUTH=<password>

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
if ! command_exist haproxy; then
    sudo apt-get update && sudo apt-get install -y haproxy
fi
# Configure HAProxy
sudo tee /etc/haproxy/haproxy.cfg <<-EOF
listen stats
        bind *:8404
        mode http
        log global
        stats enable
        stats uri /stats
        stats show-node
        stats refresh 10s
        stats auth ${STAT_USR_AUTH}:${STAT_PSW_AUTH}
frontend kubernetes-frontend
        bind *:6443
        mode tcp
        option tcplog
        default_backend kubernetes-backend
backend kubernetes-backend
        option httpchk GET /healthz
        http-check expect status 200
        mode tcp
        option ssl-hello-chk
        timeout connect 10s
        timeout client 30s
        timeout server 30s
        balance roundrobin
                server master-node-1 ${MASTER_NODE_1}:6443 check fall 3 rise 2
                server master-node-2 ${MASTER_NODE_2}:6443 check fall 3 rise 2
                server master-node-3 ${MASTER_NODE_3}:6443 check fall 3 rise 2
EOF

sudo systemctl daemon-reload && sudo systemctl restart haproxy
wait
sudo systemctl enable haproxy
