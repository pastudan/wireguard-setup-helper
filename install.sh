#!/bin/bash\

# *******************************************************
# ** A script to install WireGuard + PiHole on a       **
# ** Raspberry Pi for secure & ad-free mobile internet **
# *******************************************************

USAGE="USAGE: ./install.sh <home-ip-or-ddns>"
DDNS_ADDRESS=$1
if [ -z "$DDNS_ADDRESS" ]; then
  echo "No ddns parameter supplied"
  echo $USAGE
  exit 1
fi

# Script adapted from https://grh.am/2018/wireguard-setup-guide-for-ios/

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

apt update
apt install -y wireguard qrencode curl

# fix for resolvconf in debain which wireguard needs https://superuser.com/a/1544697
ln -s /usr/bin/resolvectl /usr/local/bin/resolvconf

# Generate priv/pub key pairs for the server & clients
wg genkey | tee /etc/wireguard/server-privatekey | wg pubkey > /etc/wireguard/server-publickey
wg genkey | tee /etc/wireguard/iphone-privatekey | wg pubkey > /etc/wireguard/iphone-publickey
wg genkey | tee /etc/wireguard/macbook-privatekey | wg pubkey > /etc/wireguard/macbook-publickey
wg genkey | tee /etc/wireguard/windows-privatekey | wg pubkey > /etc/wireguard/windows-publickey

# Generate a configuration file for the wg0 interface we just created
cat <<EOF > /etc/wireguard/wg0.conf
[Interface]
PrivateKey = $(cat /etc/wireguard/server-privatekey)
Address = 10.1.1.1/24
DNS = 10.1.1.1
ListenPort = 51820
PostUp = iptables --append FORWARD --in-interface wg0 --jump ACCEPT
PostUp = iptables --append POSTROUTING --table nat --out-interface eth0 --jump MASQUERADE
PostDown = iptables --delete FORWARD --in-interface wg0 --jump ACCEPT
PostDown = iptables --delete POSTROUTING --table nat --out-interface eth0 --jump MASQUERADE
SaveConfig = true

[Peer]
PublicKey = $(cat /etc/wireguard/iphone-publickey)
AllowedIPs = 10.1.1.2/32

[Peer]
PublicKey = $(cat /etc/wireguard/macbook-publickey)
AllowedIPs = 10.1.1.3/32

[Peer]
PublicKey = $(cat /etc/wireguard/windows-publickey)
AllowedIPs = 10.1.1.4/32
EOF

# Enable packet forward, from https://medium.com/@aveek/setting-up-pihole-wireguard-vpn-server-and-client-ubuntu-server-fc88f3f38a0a
echo -e "net.ipv4.ip_forward = 1\nnet.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.conf
sudo sysctl -p

# Start the server at boot
systemctl enable wg-quick@wg0


# Generate iphone config
cat <<EOF > /etc/wireguard/iphone.conf
[Interface]
PrivateKey = $(cat /etc/wireguard/iphone-privatekey)
Address = 10.1.1.2/32
DNS = 10.1.1.1

[Peer]
PublicKey = $(cat /etc/wireguard/server-publickey)
Endpoint = ${DDNS_ADDRESS}:51820
AllowedIPs = 0.0.0.0/0, ::/0
EOF

echo -e "***\n*** IPHONE\n***"
qrencode -t ansiutf8 < /etc/wireguard/iphone.conf

# Generate macbook config
cat <<EOF > /etc/wireguard/macbook.conf
[Interface]
PrivateKey = $(cat /etc/wireguard/macbook-privatekey)
Address = 10.1.1.3/32
DNS = 10.1.1.1

[Peer]
PublicKey = $(cat /etc/wireguard/server-publickey)
Endpoint = ${DDNS_ADDRESS}:51820
AllowedIPs = 0.0.0.0/0, ::/0
EOF


# Install PiHole
#curl -L https://install.pi-hole.net | bash
