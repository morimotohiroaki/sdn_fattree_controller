echo "<network>
<name>network-$1</name>
<forward mode='bridge'/>
<bridge name='$1'/>
<virtualport type='openvswitch'/>
</network>" > network-$1.xml
sudo virsh net-define network-$1.xml
sudo virsh net-start network-$1
sudo virsh net-autostart network-$1
rm network-$1.xml
