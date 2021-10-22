from ubuntu
run apt-get update --fix-missing
run DEBIAN_FRONTEND="noninteractive" apt-get install curl build-essential openssh-server rsyslog -y
run apt-get install net-tools -y
run curl https://nginx.org/download/nginx-1.20.1.tar.gz > /tmp/nginx.tar
workdir /tmp
run tar -xvf nginx.tar
run rm /tmp/nginx.tar
workdir /tmp/nginx-1.20.1
run apt-get install libpcre3-dev zlib1g-dev gettext-base -y
run ./configure --with-http_slice_module
run make
run make install
run mv /usr/local/nginx/sbin/nginx /usr/sbin
workdir /
copy volekino.conf /usr/local/nginx/conf/nginx.conf.tempalte
copy ./sshd_config /etc/ssh/sshd_config
copy ./rsyslog.conf /etc/rsyslog.conf
copy ./favicon.ico /var/www/html/favicon.ico
copy ./fonts /var/www/html/fonts
run mkdir /var/run/sshd
copy ./volekino_proxy /usr/local/bin/volekino_proxy
copy ./rpc_controller /usr/local/bin/rpc_controller
env SLICE_SIZE=1m
env PROXY_CACHE_MAX_SIZE=2G
cmd /usr/local/bin/volekino_proxy
