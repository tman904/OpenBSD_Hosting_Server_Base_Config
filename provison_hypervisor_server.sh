#!/bin/sh

#Date: 3/5/2025 @20:23 hours
#Author: Tyler K Monroe aka tman904
#Purpose: Provison OpenBSD hypervisor server from a fresh greenfield install of OpenBSD.

iso="install76.iso"
ver="7.6"

rcctl stop vmd
rcctl disable vmd

pfctl -F all
pfctl -d
cp /etc/pf.conf /etc/pf.conf.bak

pkg_add openvpn

#Create customer shell account called cust
adduser

#Make restricted shell for user cust
echo "#!/bin/sh\n\n" > /home/cust/cust.sh
echo "doas vmctl console cust" >> /home/cust/cust.sh
chown cust:cust /home/cust/cust.sh
chmod u+x /home/cust/cust.sh

#Change cust users shell to cust.sh
usermod -s /home/cust/cust.sh cust

cd /home/cust

#Make first VM also use this a a templete to save time and increase scalability.
ftp https://cdn.openbsd.org/pub/OpenBSD/$ver/amd64/$iso
rcctl enable vmd
rcctl start vmd
vmctl create -s 10G /home/cust/cust.qcow2
vmctl start -m 1G -L -i 1 -r /home/cust/$iso -d /home/cust/cust.qcow2 cust
vmctl console cust


#create needed files and their contents. I put them in this script to minimize needing an internet connection

#/etc/vm.conf file

echo "vm \"cust\" {\n" > /etc/vm.conf

echo "	memory 1G \n" >> /etc/vm.conf
echo "	disk /home/cust/cust.qcow2\n" >> /etc/vm.conf
echo "	enable\n" >> /etc/vm.conf
echo "	local interface\n" >> /etc/vm.conf
echo "}\n" >> /etc/vm.conf

#/etc/sysctl.conf file
echo "net.inet.ip.forwarding=1" > /etc/sysctl.conf

#/etc/pf.conf file

echo "wan=\"iwx0\"" > /etc/pf.conf
echo "custnet=\"100.64.0.0/10\"" >> /etc/pf.conf
echo "vpn=\"tun0\"" >> /etc/pf.conf
echo "cust=\"tap0\"" >> /etc/pf.conf
echo "table <priv_nets> { 192.168.0.0/16 10.0.0.0/8 172.16.0.0/12 }" >> /etc/pf.conf

echo "set skip on lo0" >> /etc/pf.conf
echo "set block-policy drop" >> /etc/pf.conf

echo "block drop log all" >> /etc/pf.conf

echo "block drop quick from \$custnet to <priv_nets>" >> /etc/pf.conf 
echo "pass in on \$vpn from any to any keep state" >> /etc/pf.conf
echo "pass in on \$cust from \$custnet to any keep state" >> /etc/pf.conf
echo "pass out on \$cust from any to any keep state" >> /etc/pf.conf
echo "pass in on \$cust inet proto udp from \$custnet to any rdr-to 8.8.8.8 port 53 keep state" >> /etc/pf.conf
echo "pass out on \$wan inet proto tcp from \$custnet to any port 80 nat-to (\$wan) keep state" >> /etc/pf.conf
echo "pass out on \$wan inet proto tcp from \$custnet to any port 443 nat-to (\$wan) keep state" >> /etc/pf.conf
echo "pass out on \$wan inet proto tcp from \$custnet to any port 21 nat-to (\$wan) keep state" >> /etc/pf.conf
echo "pass out on \$wan inet proto icmp from \$custnet to any nat-to (\$wan) keep state" >> /etc/pf.conf
echo "pass out on \$wan inet proto udp from \$custnet to 8.8.8.8 port 53 nat-to (\$wan) keep state" >> /etc/pf.conf

echo "pass in on \$wan inet proto tcp from any to port 22 keep state" >> /etc/pf.conf
echo "pass from self" >> /etc/pf.conf

#/etc/doas.conf file

echo "permit nopass cust as root cmd vmctl" > /etc/doas.conf


sysctl net.inet.ip.forwarding=1
pfctl -f /etc/pf.conf
pfctl -e

