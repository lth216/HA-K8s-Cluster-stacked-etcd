#!/bin/bash
set -eou pipefail
[[ -n ${DEBUG:-} ]] && set -x

KEEPALIVED_VIRTUAL_IP=<IP_ADDRESS>     #Change here
HOST_NAME=<SOME_NAME>                  #Change here
INTERFACE=<INTERFACE>                  #Change here
AUTH_PASS=<PASS>                       #Change here

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
sudo tee /etc/keepalived/keepalived.conf <<-EOF
global_defs {
  router_id ${HOST_NAME}
}
vrrp_script chk_haproxy {
  script "killall -0 haproxy"
  interval 2
  weight 2
}
vrrp_instance VI_1 {
  virtual_router_id 51
  advert_int 1
  priority 100
  state MASTER
  interface ${INTERFACE}
  virtual_ipaddress {
    ${KEEPALIVED_VIRTUAL_IP} dev ${INTERFACE}
  }
  authentication {
    auth_type PASS
    auth_pass ${AUTH_PASS}
  }
  track_script {
    chk_haproxy
  }
}
EOF

sudo service keepalived start
wait
sudo systemctl enable keepalived.service
