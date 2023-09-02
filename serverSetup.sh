#!/bin/bash

# This script was designed to setup a fresh Debian 11/12 installation for production use.
# Nothing in this script is guaranteed, and best practices are slowly being added.
# Reach out to boobcactus with questions or concerns.
 
read -p "What is the server's hostname? " HOSTNAME
read -rsp "Please provide a new root password: " ROOTPASS
read -rsp "Now provide a password for the sudo user account: " USERPASS
passwd root <<< "$ROOTPASS"
echo "Root password updated."
apt update && apt upgrade && apt install sudo -y
timedatectl set-timezone UTC
echo "Timezone set."
useradd -m -s /bin/bash user && usermod -aG sudo user
passwd user <<< "$USERPASS"
echo "User created."
su - user
sudo apt update && sudo apt upgrade && sudo apt install git curl wget aria2 ufw make build-essential jq lz4 -y
echo "Updates installed."

# BEGIN GO INSTALLATION
mkdir go && mkdir ~/go/bin
LATEST_VERSION=$(curl -s https://go.dev/dl/ | grep -oP 'go\d+\.\d+\.\d+' | head -n 1)
DOWNLOAD_URL="https://go.dev/dl/${LATEST_VERSION}.linux-amd64.tar.gz"
wget $DOWNLOAD_URL && sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf ${LATEST_VERSION}.linux-amd64.tar.gz
rm ${LATEST_VERSION}.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
export PATH=$PATH:/home/user/go/bin
source ~/.bashrc
echo "$LATEST_VERSION has been installed."
exit #back to root

# BEGIN SSH CONFIGURATION
sed -i 's/PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/#MaxSessions 10/MaxSessions 5/' /etc/ssh/sshd_config
sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
sed -i 's/#UseDNS no/UseDNS no/' /etc/ssh/sshd_config
if ! sshd -t -f /etc/ssh/sshd_config; then
    echo "Error: SSH config is invalid. Refusing to update."
    exit 1
fi
echo "SSH config updated."

# CORRECT HOSTS FILE 
sudo cp /etc/hosts /etc/hosts.bak
if ! grep -q "^127.0.0.1" /etc/hosts; then
    sudo sed -i "1i 127.0.0.1 localhost" /etc/hosts
fi
if ! grep -q "^::1" /etc/hosts; then
    sudo sed -i "2i ::1 localhost" /etc/hosts
fi
sudo sed -i "/^127.0.0.1/s/$/ $HOSTNAME/" /etc/hosts
sudo sed -i "/^::1/s/$/ $HOSTNAME/" /etc/hosts
echo "Hosts file updated."

# FINAL STEPS - MAY LOG USER OUT
ufw allow 2222
ufw enable
systemctl restart sshd

echo "Setup complete."