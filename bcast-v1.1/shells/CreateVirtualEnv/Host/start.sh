
# configuration on host server


sudo yum update -y
sudo yum remove NetworkManager
sudo yum install wget emacs man -y
wget -b http://ftp.riken.jp/Linux/centos/6.5/isos/x86_64/CentOS-6.5-x86_64-minimal.iso

# setting host name
# sudo ./hostname.sh ipaddress host-name
sudo ./hostname.sh

# setting ssh
echo "Setting up ssh..."
mkdir ~/.ssh
chmod 700 ~/.ssh
cat authorized_keys >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

echo "Installing openvswitch..."
sudo yum localinstall ovs-rpm/kmod-openvswitch-1.11.0-1.el6.x86_64.rpm -y
sudo yum localinstall ovs-rpm/openvswitch-1.11.0-1.x86_64.rpm -y
sudo chkconfig openvswitch on
sudo service openvswitch start

# installing kvm                                                                                                        
echo "Installing qemu-kvm..."
sudo yum install -y qemu-kvm qemu-img
sudo yum install -y virt-manager libvirt bridge-utils
sudo service libvirtd start
sudo chkconfig libvirtd on

echo "Consructing network..."
echo "Creating ovs bridges..."
sudo ovs-vsctl add-br br0
sudo ovs-vsctl add-br br1
sudo ovs-vsctl add-br br2
sudo ovs-vsctl add-br brlocal
sudo virsh iface-bridge em1 brout
echo "Connecting bridges..."
sudo ovs-vsctl add-port br0 cable0-1 -- set Interface cable0-1 type=patch options:peer=cable1-0
sudo ovs-vsctl add-port br0 cable0-2 -- set Interface cable0-2 type=patch options:peer=cable2-0
sudo ovs-vsctl add-port br1 cable1-0 -- set Interface cable1-0 type=patch options:peer=cable0-1
sudo ovs-vsctl add-port br2 cable2-0 -- set Interface cable2-0 type=patch options:peer=cable0-2

# ./create-network.sh bridge-name
./create-network.sh br0
./create-network.sh br1
./create-network.sh br2
./create-network.sh brlocal

# ./master.sh vm-id sdn-bridge local-bridge outside-bridge

# ./slave.sh vm-id sdn-bridge local-bridge
