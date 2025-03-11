#!/bin/sh

#Date: 3/5/2025 @20:23 hours
#Author: Tyler K Monroe aka tman904
#Purpose: Provison OpenBSD hypervisor server from a fresh greenfield install of OpenBSD.

iso="install76.iso"
ver="7.6"
arch="amd64"

#clean up and start fresh
echo "Cleaning up first"
sleep 3
cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
rm /etc/ssh/sshd_config.bak
rcctl restart sshd
rcctl stop vmd
rcctl disable vmd
rm /etc/vm.conf
rm /etc/sysctl.conf
sysctl net.inet.ip.forwarding=0
pfctl -F all
pfctl -d
cp /etc/pf.conf /etc/pf.conf.bak
rm /etc/pf.conf
rm /etc/doas.conf
rm -rf /home/demo
rcctl stop nginx
rcctl disable nginx
rm /var/www/htdocs/install.conf
pkg_delete nginx
pkg_delete openvpn
userdel _openvpn
groupdel _openvpn
pkg_delete -a
echo "Done cleaning up\n\n"
sleep 3

echo "Starting fresh configuration"
sleep 3

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
echo "Port 222" >>/etc/ssh/sshd_config
rcctl restart sshd

#The 2 dashes at the end of pkg name accept the default version without them you have to manually enter a selection.
pkg_add openvpn--
pkg_add nginx--
rcctl enable nginx

#Thank you for documenting this process Eric Radman!
#https://eradman.com/posts/autoinstall-openbsd.html
#Make autoinstall file contents nginx web server serves this to the VM or any system on the same network really!
echo "System hostname = demo" > /var/www/htdocs/install.conf
echo "Password for root = demo" >> /var/www/htdocs/install.conf
echo "Setup a user = demo" >> /var/www/htdocs/install.conf
echo "Password for user demo = demo" >> /var/www/htdocs/install.conf
echo "Network interfaces = vio0" >> /var/www/htdocs/install.conf
echo "IPv4 address for vio0 = dhcp" >> /var/www/htdocs/install.conf
echo "Which disk is the root disk = sd0" >> /var/www/htdocs/install.conf
echo "Location of sets = cd0" >> /var/www/htdocs/install.conf
echo "Set name(s) = -all bsd* base* etc* man*" >> /var/www/htdocs/install.conf
echo "Continue without verification = yes" >> /var/www/htdocs/install.conf


rcctl restart nginx

mkdir /home/demo
cd /home/demo

#Make first VM also use this a a templete to save time and increase scalability.
ftp https://cdn.openbsd.org/pub/OpenBSD/$ver/$arch/$iso
rcctl enable vmd
rcctl start vmd
vmctl create -s 10G /home/demo/demo.qcow2
vmctl start -m 1G -L -i 1 -r /home/demo/$iso -d /home/demo/demo.qcow2 demo
vmctl console demo


#create needed files and their contents. I put them in this script to minimize needing an internet connection

#/etc/vm.conf file

echo "vm \"demo\" {\n" > /etc/vm.conf

echo "	memory 1G \n" >> /etc/vm.conf
echo "	disk /home/demo/demo.qcow2\n" >> /etc/vm.conf
echo "	enable\n" >> /etc/vm.conf
echo "	local interface\n" >> /etc/vm.conf
echo "}\n" >> /etc/vm.conf

#/etc/sysctl.conf file
echo "net.inet.ip.forwarding=1" > /etc/sysctl.conf

#vpn macro maps to openvpn's tun0 interface. custnet macro maps to layer 3 subnet that all VMs are logically connected to inside of host OS/hypervisors network stack. Interface tap0 which is the layer 3 subnet for all the VMs running in VMD/VMM.
#I built this program on a laptop so my "wan" interface is a wireless card.
#priv_nets table will need to be adjusted to your network environments needs.

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
#The rule below this comment makes DNS work in the VMs you can't adjust the VM DNS settings inside /etc/vm.conf it has to be a NAT rule in /etc/pf.conf
echo "pass in on \$cust inet proto udp from \$custnet to any rdr-to 8.8.8.8 port 53 keep state" >> /etc/pf.conf
echo "pass in on \$vpn inet proto tcp from any to any rdr-to 100.64.1.3 port 22 keep state" >> /etc/pf.conf
echo "pass out on \$wan inet proto tcp from \$custnet to any port 80 nat-to (\$wan) keep state" >> /etc/pf.conf
echo "pass out on \$wan inet proto tcp from \$custnet to any port 443 nat-to (\$wan) keep state" >> /etc/pf.conf
echo "pass out on \$wan inet proto tcp from \$custnet to any port 21 nat-to (\$wan) keep state" >> /etc/pf.conf
echo "pass out on \$wan inet proto icmp from \$custnet to any nat-to (\$wan) keep state" >> /etc/pf.conf
echo "pass out on \$wan inet proto udp from \$custnet to 8.8.8.8 port 53 nat-to (\$wan) keep state" >> /etc/pf.conf
#This allows any system including the VMs to talk to the nginx web server installed earlier to let them get the install.conf file to make the automated install work correctly inside of the VMs. This can also work on a physical system too the same way.
echo "pass inet proto tcp from any to any port 80 keep state" >> /etc/pf.conf

echo "pass in on \$wan inet proto tcp from any to port 222 keep state" >> /etc/pf.conf
echo "pass from self" >> /etc/pf.conf

#This kernel variable lets the hypervisors network stack route packets from the VMs layer 3 interface/subnet on tap0 to the wan interface iwx0 in my case. Which is the real physical network that the host OS/hypervisor is attached to.
sysctl net.inet.ip.forwarding=1
pfctl -f /etc/pf.conf
pfctl -e

#Connect to VPN for remote internet access I want to change this to use a Internet facing public IP Address/network instead, but for now this is all I have to use.
openvpn /root/access_vpn.ovpn
