sudo virsh destroy $1
sudo virsh undefine $1
sudo virsh vol-delete /var/lib/libvirt/images/$1.img