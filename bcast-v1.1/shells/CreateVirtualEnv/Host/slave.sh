
# ./slave.sh vm-id(01, 10) sdn-bridge local-bridge

sudo virt-install --name vm0$1 --vcpus 3 --ram 1024 --disk path=/var/lib/libvirt/images/vm0$1.img,size=5 --location http://ftp.riken.jp/Linux/centos/6.5/os/x86_64 --os-type linux --nographics --accelerate --extra-args="console=ttyS0" --network network=network-$2,model=virtio,mac=00:00:00:00:00:0$1  --network network=network-$3,model=virtio,mac=aa:00:00:00:00:0$1
