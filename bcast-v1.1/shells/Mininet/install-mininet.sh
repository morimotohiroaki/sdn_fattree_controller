
echo "Getting minimal centos..."
wget -b -o ~/centos-minimal.iso http://ftp.riken.jp/Linux/centos/6.5/isos/x86_64/CentOS-6.5-x86_64-minimal.iso

sudo yum remove NetworkManager
sudo yum update -y

sudo echo "$1 $2" >> /etc/hosts
sudo yum -y install wget git emacs

echo "Setting up ssh..."
mkdir ~/.ssh
chmod 700 ~/.ssh
cat authorized_keys >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

echo "Installing mininet..."
sudo cp repos/*.repo /etc/yum.repos.d/
sudo rpm --import http://puias.princeton.edu/data/puias/6/x86_64/os/RPM-GPG-KEY-puias
sudo yum -y install mininet
sudo yum -y update

echo "Installing kvm..."
sudo yum install -y qemu-kvm qemu-img 
sudo yum install -y virt-manager libvirt virt-viewer
sudo service libvirtd start
sudo chkconfig libvirtd on

