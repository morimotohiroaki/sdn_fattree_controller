
# ./slave vm-id(1,2)
# configuration on host server

yum update -y
yum remove NetworkManager
yum install wget emacs man -y

# setting host name                                                                                                     
echo "133.1.134.54 venus" >> /etc/hosts
echo "133.1.134.53 pluto" >> /etc/hosts
echo "10.0.0.1 vm01e" >> /etc/hosts
echo "10.0.0.2 vm02e" >> /etc/hosts
echo "10.0.0.3 vm03e" >> /etc/hosts
echo "10.0.0.4 vm04e" >> /etc/hosts
echo "192.168.1.1 vm01" >> /etc/hosts
echo "192.168.1.2 vm02" >> /etc/hosts
echo "192.168.1.3 vm03" >> /etc/hosts
echo "192.168.1.4 vm04" >> /etc/hosts

# iptable setting
service iptables stop
chkconfig iptables off

# setting up network
echo "NETWORKING=yes
HOSTNAME=vm0$1
GATEWAY=192.168.1.1
" > /etc/sysconfig/network

echo "DEVICE=eth0
HWADDR=00:00:00:00:00:0$1
TYPE=Ethernet
ONBOOT=yes                                                                                                              
IPADDR=10.0.0.$1
NETMASK=255.255.255.0
" > /etc/sysconfig/network-scripts/ifcfg-eth0

service network restart

# nfs settings                                                                                                          
yum install nfs-utils -y
echo "vm01:/root /root nfs hard;intr 0 0" >> /etc/fstab
chkconfig rpcbind on
service rpcbind start
mount -t nfs vm01:/root /root


