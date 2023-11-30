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
read -rp "What is the server's hostname? " HOSTNAME
if [ -z "$HOSTNAME" ]; then
    echo "Error: Hostname cannot be empty."
    exit 1
fi
read -rsp "Please provide a new root password: " ROOTPASS
echo -e "\n\c"
if [ -z "$ROOTPASS" ]; then
    echo "Error: Root password cannot be be empty."
    exit 1
fi
read -rsp "Now provide a password for the sudo user account: " USERPASS
echo -e "\n\c"
if [ -z "$USERPASS" ]; then
    echo "Error: Sudo user password cannot be empty."
    exit 1
fi
sudo apt update && sudo apt upgrade -y && sudo apt install git curl wget aria2 ufw make build-essential jq lz4 nginx fail2ban sudo -y
if [ $? -ne 0 ]; then
    echo "Error: System update or package installation failed."
    exit 1
fi
sudo timedatectl set-timezone UTC
if [ $? -ne 0 ]; then
    echo "Error: Failed to set the system timezone to UTC."
    exit 1
fi
echo "Timezone set to UTC."
echo "root:$ROOTPASS" | sudo chpasswd
if [ $? -ne 0 ]; then
    echo "Error: Failed to update the root password."
    exit 1
fi
echo "Root password updated."
if id "user" &>/dev/null; then
    echo "User 'user' already exists. Updating password."
    echo "user:$USERPASS" | sudo chpasswd
    if [ $? -ne 0 ]; then
        echo "Error: Failed to update the password for user 'user'."
        exit 1
    fi
else
    echo "User 'user' does not exist. Creating user and setting password."
    sudo useradd -m -s /bin/bash user && sudo usermod -aG sudo user && echo "user:$USERPASS" | sudo chpasswd
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create the sudo user 'user' or set the user password."
        exit 1
    fi
fi
echo "Sudo user 'user' created and password updated."

# BEGIN GO INSTALLATION
if [ ! -d "/home/user/go" ]; then
    mkdir /home/user/go
fi
if [ ! -d "/home/user/go/bin" ]; then
    mkdir /home/user/go/bin
fi
if [ $? -ne 0 ]; then
    echo "Error: Failed to create Go directories."
    exit 1
fi
LATEST_VERSION=$(curl -s https://go.dev/dl/ | grep -oP 'go\d+\.\d+\.\d+' | head -n 1)
if [ -z "$LATEST_VERSION" ]; then
    echo "Error: Failed to retrieve the latest Go version."
    exit 1
fi
DOWNLOAD_URL="https://go.dev/dl/${LATEST_VERSION}.linux-amd64.tar.gz"
wget "$DOWNLOAD_URL" && sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf "${LATEST_VERSION}.linux-amd64.tar.gz"
rm "${LATEST_VERSION}.linux-amd64.tar.gz"
if [ $? -ne 0 ]; then
    echo "Error: Failed to download and install Go."
    exit 1
fi
export PATH=$PATH:/usr/local/go/bin
export PATH=$PATH:/home/user/go/bin
if [ $? -ne 0 ]; then
    echo "Error: Failed to update the PATH environment variable."
    exit 1
fi
source ~/.bashrc
if [ $? -ne 0 ]; then
    echo "Error: Failed to source the .bashrc file."
    exit 1
fi
echo "$LATEST_VERSION has been installed."

# BEGIN SSH CONFIGURATION
sed -i 's/#PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
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
if [ $? -ne 0 ]; then
    echo "Error: Failed to backup the hosts file."
    exit 1
fi
if ! grep -q "^127.0.0.1" /etc/hosts; then
    sudo sed -i "1i 127.0.0.1 localhost" /etc/hosts
    if [ $? -ne 0 ]; then
        echo "Error: Failed to insert the loopback address in /etc/hosts."
        exit 1
    fi
fi
if ! grep -q "^::1" /etc/hosts; then
    sudo sed -i "2i ::1 localhost" /etc/hosts
    if [ $? -ne 0 ]; then
        echo "Error: Failed to insert the IPv6 loopback address in /etc/hosts."
        exit 1
    fi
fi
sudo sed -i "/^127.0.0.1/s/$/ $HOSTNAME/" /etc/hosts
sudo sed -i "/^::1/s/$/ $HOSTNAME/" /etc/hosts
if [ $? -ne 0 ]; then
    echo "Error: Failed to add the server's hostname to /etc/hosts."
    exit 1
fi
echo "Hosts file updated."

# SET UP FAIL2BAN
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
if [ $? -ne 0 ]; then
    echo "Error: Failed to copy the Fail2Ban configuration file."
    exit 1
fi
file="/etc/fail2ban/jail.local"
sed -i 's|backend = auto|backend = systemd|g' "$file"
sed -i 's|bantime  = 10m|bantime  = 11m|g' "$file"
sed -i 's|maxretry = 5|maxretry = 7|g' "$file"
sed -i 's|port    = ssh|port    = 2222|' "$file"
if [ $? -ne 0 ]; then
    echo "Error: Failed to modify the Fail2Ban configuration file."
    exit 1
fi
echo "Changes have been made in $file"

# FINAL STEPS - MAY LOG USER OUT
sudo ufw allow 2222
if [ $? -ne 0 ]; then
    echo "Error: Failed to configure UFW to allow SSH on port 2222."
    exit 1
fi
sudo ufw enable
if [ $? -ne 0 ]; then
    echo "Error: Failed to enable UFW."
    exit 1
fi
sudo systemctl restart sshd
if [ $? -ne 0 ]; then
    echo "Error: Failed to restart the SSH service."
    exit 1
fi
sudo systemctl restart fail2ban
if [ $? -ne 0 ]; then
    echo "Error: Failed to restart the Fail2Ban service."
    exit 1
fi
echo "Setup complete. No reboot is required unless a kernel update was applied."
