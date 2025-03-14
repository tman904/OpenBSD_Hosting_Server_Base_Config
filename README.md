I didn't have a public static IP address of any kind to host from so I used a VPN openvpn access server in this case to make things easier to manage. I put the VPN on a digitalocean droplet it doesn't have to have a DNS A record but mine does in this case. My droplet has 1vcpu 10G disk space and 1G of ram. It costs $6.00/month USD to run it. Any less ram and the VPN server crashes so 1G is the minimum amount of ram you need.

For WAN access for users if the budget allows you can purchase if you are in the United States at least I can't speak for other countries. A cheaper MVNO cell phone plan and use a cheaper android smartphone that supports mobile hotspot function. You use this to connect your system running OpenBSD to the Internet. This will also allow the server and users to connect into the VPN mentioned in step 2 to allow a logical tunnel to be made between the user and openbsd server. Later we will configure the VPN to always give the same IP address to the server on the VPN tunnel network. This will create a static IP address and since the user is connected to the VPN on the same broadcast domain they will always be able to access the server using this static IP address. Even though in reality the server is connected to a dynamic/DHCP IP address of an ISP or even in some cases an ISP that uses CGNAT. This will cost around $25.00-$50.00/month to run.

Note if you can't afford the MVNO Service you can also as a last resort use TOR and connect the user and server together in a similar way except for the fact you would lose the ability to have any form of static IP addressing on the server other than maybe using an .onion address. For WAN access in the case of TOR you could use free open wifi somewhere around you. I would not recommend doing this project with TOR.



1. Install OpenBSD on a system with an x86_64 bit CPU that has the CPU features VT-x and VT-d and or AMD versions of those virtualization acceleration features.  I used an intel i5-1235U on my system in a dell insprion 15-3520 I believe with 16G of DDR4 RAM less should still work ok. Here is the support page for the model I used for this project if you want to copy this exactly. https://www.dell.com/support/product-details/en-us/product/inspiron-15-3520-laptop

2. Login to your system running the VPN server eg https://X.X.X.X:943/admin

3. Create a second admin account with a different name and disable the default one called openvpn.

4. Create two users one called "demo" and another called "server".

5. Disable the VPN setting that allows it to be used as a gateway/proxy. This stops your VPN server becoming a proxy for other users.

6. Under the VPNs network settings put a subnet in the field that says static ip addressing pool/subnet I put 10.255.255.0/24 in it.

7. Under the "server" users settings assign click the radio box that assigns a static ip address to the user and set it to 10.255.255.2/24.

8. Under the "demo" users settings you can repeat the same as for the server user except put 10.255.255.3/24.

9. Now on any system that has access to the VPN server web gui. Open https://X.X.X.X:943 login as user "demo" and download the connection profile you need for your OS. This is a .ovpn file that holds the public/private keys and IP addressing information needed to connect to the VPN server. Make sure to rename it to "access_vpn.ovpn" and place it inside of "/root" the script will not find it if not in that path.

10. Repeat the steps of step 9 but for the "server" user instead. Either download the .ovpn file directly to the server or download on another system then use scp to put it on the server.

11. Disable the "server" and "demo" users ability to change their own passwords in the web gui. You don't need to do this but it keeps control of user access to the admin. 

12. For ease of use and automation you can edit the .ovpn and put the username and password inside of the file this makes openvpn put the username and password values in automatically instead of you having to type them.
On any newline/blank line in the .ovpn file add this:

Wrap the user and password inside of brackets XML start and stop tags style with "auth-user-pass" as the name.
someusername
somepassword


13. Repeat step 12 for this step but on the server with the "server" users .ovpn file.

14. On the server run the "provision_hypervisor_server.sh" located in this github repo. DO NOT run this over ssh it will kill the connection and the rest of the scripts setup procedure once pf is enabled.

15. Now you should be able to connect to the VPN on the client system.

16. Once connected to the VPN as the "demo" user and the "server" use is also connected properly. You can use "ssh demo@10.255.255.2" and you should now have ssh access from the client into the server.

Note you can also install web servers inside of the VM and access them using the hypervisor servers VPN IP address 10.255.255.2 in this example. This could be expanded to support more types of server programs in the VMs. 

Note I've only allowed tcp ports 80, 443 and 21 out of the VM to the internet. Along with UDP port 53. No icmp is allowed out from the VMs to prevent things like traceroute from being used. This configuration prevents pentesting and tor use from the VM out to the internet at large.
