
# configuration on master server

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


# master settings
echo 1 > /proc/sys/net/ipv4/ip_forward
[ -f ./iptables.bak ] && echo "backed up" || cp /etc/sysconfig/iptables ./iptables.bak
cat iptables.tmp /etc/sysconfig/iptables
service iptables restart

# nfs settings                                                                                                          
yum install nfs-utils -y
echo "/root 192.168.1.0/24(rw,no_root_squash)" >> /etc/exports
exportfs -a
chkconfig rpcbind on
service rpcbind start

chkconfig nfs on
service nfs start

# setting up network
echo "NETWORKING=yes                                                                                                    
HOSTNAME=venus                                                                                                          
GATEWAY=133.1.134.1                                                                                                     
" > /etc/sysconfig/network

echo "DEVICE=eth0                                                                                                       
HWADDR=00:00:00:00:00:01                                                                                                
TYPE=Ethernet                                                                                                           
ONBOOT=yes                                                                                                              
IPADDR=10.0.0.1                                                                                                         
NETMASK=255.255.255.0                                                                                                   
" > /etc/sysconfig/network-scripts/ifcfg-eth0

echo "DEVICE=eth1                                                                                                       
HWADDR=aa:00:00:00:00:01                                                                                                
TYPE=Ethernet                                                                                                           
ONBOOT=yes                                                                                                              
IPADDR=192.168.1.1                                                                                                      
NETMASK=255.255.255.0                                                                                                   
" > /etc/sysconfig/network-scripts/ifcfg-eth1

service network restart

# install openmpi
yum install make gcc gcc-c++ gcc-gfortran -y

wget http://www.open-mpi.org/software/ompi/v1.6/downloads/openmpi-1.6.5.tar.gz
tar zxf openmpi-1.6.5.tar.gz
(cd openmpi-1.6.5;
./configure --prefix=/root/openmpi/ --disable-mpi-cxx --disable-mpi-f77 --disable-mpi-f90;
make;
make install;)

echo "
LD_LIBRARY_PATH=/root/openmpi/lib
PATH=$PATH:/root/openmpi/bin                                                                                            

export LD_LIBRARY_PATH
export PATH
" >> ~/.bashrc
source ~/.bashrc

# setting ssh
echo "Setting up ssh..."
ssh-keygen
cat authorized_keys >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
echo '    StrictHostKeyChecking no' >> /etc/ssh/ssh_config
service sshd restart
