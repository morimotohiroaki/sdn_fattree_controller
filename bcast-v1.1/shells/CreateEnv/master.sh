

yum update -y
yum install -y emacs yum-utils
yum install -y man man-pages

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


# nfs settings
yum install nfs-utils -y
echo "/root 192.168.1.0/24(rw,no_root_squash)" >> /etc/exports
echo "/home/huchka 192.168.1.0/24(rw,no_root_squash)" >> /etc/exports
chkconfig rpcbind on
service rpcbind restart
chkconfig nfs on
service nfs start

