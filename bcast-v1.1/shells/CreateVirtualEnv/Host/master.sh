
# ./master.sh sdn-bridge local-bridge outside-bridge

sudo virt-install --name vm01 --vcpus 3 --ram 1024 --disk path=/var/lib/libvirt/images/vm01.img,size=5 --location http://ftp.riken.jp/Linux/centos/6.5/os/x86_64 --os-type linux --nographics --accelerate --extra-args="console=ttyS0" --network network=network-$1,model=virtio,mac=00:00:00:00:00:01  --network network=network-$2,model=virtio,mac=aa:00:00:00:00:01 --network bridge=$3,model=virtio,mac=aa:aa:00:00:00:01