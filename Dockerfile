from ubuntu
run apt update --fix-missing
run apt install nginx openssh-server rsyslog -y
run apt install curl net-tools -y
copy volekino.conf /etc/nginx/sites-enabled/default
copy ./sshd_config /etc/ssh/sshd_config
copy ./rsyslog.conf /etc/rsyslog.conf
run mkdir /var/run/sshd
copy ./volekino_proxy /usr/local/bin/volekino_proxy
cmd /usr/local/bin/volekino_proxy
