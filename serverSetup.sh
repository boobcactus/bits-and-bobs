#!/bin/bash

# This script was designed to setup a fresh Debian 11/12 installation for production use.
# Nothing in this script is guaranteed, and best practices are slowly being added.
# Reach out to boobcactus with questions or concerns.

# SUDO CHECK
if [ "$UID" -ne 0 ]; then
    echo "Error: This script must be run with sudo."
    exit 1
fi

# BEGIN HOST CONFIGURATION
read -p "What is the server's hostname? " HOSTNAME
read -rsp "Please provide a new root password: " ROOTPASS
echo -e "\n\c"
read -rsp "Now provide a password for the sudo user account: " USERPASS
echo -e "\n\c"
sudo apt update && sudo apt upgrade -y && sudo apt install git curl wget aria2 ufw make build-essential jq lz4 sudo -y
sudo timedatectl set-timezone UTC
echo "Timezone set to UTC."
echo "root:$ROOTPASS" | sudo chpasswd
echo "Root password updated."
sudo useradd -m -s /bin/bash user 
sudo usermod -aG sudo user
echo "user:$USERPASS" | sudo chpasswd
echo "Sudo user created and password updated."

# BEGIN GO INSTALLATION
mkdir /home/user/go && mkdir /home/user/go/bin
LATEST_VERSION=$(curl -s https://go.dev/dl/ | grep -oP 'go\d+\.\d+\.\d+' | head -n 1)
DOWNLOAD_URL="https://go.dev/dl/${LATEST_VERSION}.linux-amd64.tar.gz"
wget $DOWNLOAD_URL && sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf ${LATEST_VERSION}.linux-amd64.tar.gz
rm ${LATEST_VERSION}.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
export PATH=$PATH:/home/user/go/bin
source ~/.bashrc
echo "$LATEST_VERSION has been installed."

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