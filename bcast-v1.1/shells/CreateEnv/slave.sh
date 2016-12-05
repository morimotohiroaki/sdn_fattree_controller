
yum update -y
yum install -y emacs man yum-utils gcc

# installing debugger
yum install -y gdb
echo "enabled=1" >> /etc/yum.repos.d/CentOS-Debuginfo.repo
debuginfo-install glibc libgcc -y


useradd huchka

echo "133.1.134.200 neptune
192.168.1.1 master
192.168.1.2 cluster01
192.168.1.3 cluster02
192.168.1.4 cluster03
192.168.1.5 cluster04
192.168.1.6 cluster05
10.0.0.1 mastere
10.0.0.2 cluster01e
10.0.0.3 cluster02e
10.0.0.4 cluster03e
10.0.0.5 cluster04e
10.0.0.6 cluster05e" >> /etc/hosts

# iptables setting
service iptables stop
chkconfig iptables off

# nfs settings
yum install nfs-utils -y
echo "master:/root /root nfs hard;intr 0 0" >> /etc/fstab
echo "master:/home/huchka /home/huchka nfs hard;intr 0 0" >> /etc/fstab
chkconfig rpcbind on
service rpcbind restart
mount -t nfs master:/root /root
mount -t nfs master:/home/huchka /home/huchka
