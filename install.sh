#!/bin/bash

is_number() {
    [[ $1 =~ ^[0-9]+$ ]]
}

YELLOW='\033[1;33m'
NC='\033[0m'

if [ "$(whoami)" != "root" ]; then
    echo "Error: This script must be run as root."
    exit 1
fi

cd /root
clear

echo ""
echo -e "\033[1;33mZivpn UDP Services\033[0m"
echo -e "\033[1;32m1. Zivpn Udp\033[0m"
echo -e "\033[1;32m2. Create Auth \033[0m"
echo -e "\033[1;32m3. Active Users  \033[1;0m"
echo -e "\033[1;32m0. Exit \033[0m"

read -p "$(echo -e "\033[1;33mSelect a number from 0 to 3: \033[0m")" input

if ! is_number "$input"; then
    echo -e "$YELLOW"
    echo "Invalid input. Please enter a valid number."
    echo -e "$NC"
    exit 1
fi

clear

case $input in
    1)
        echo -e "\033[1;33mInstalling ZIVPN Hysteria Udp...\033[0m"

        cd /root
        systemctl stop ziv-server.service
        systemctl disable ziv-server.service
        rm -rf /etc/systemd/system/ziv-server.service
        rm -rf /root/zv

        mkdir zv
        cd zv

        # Download latest ziv-linux-amd64 from GitHub
        latest_release=$(curl -s https://api.github.com/repos/Hyper-21-stack/ziv-linux/releases/latest | grep "browser_download_url" | cut -d '"' -f 4)
        
        if [ -z "$latest_release" ]; then
            echo -e "$YELLOW"
            echo "Error: Could not fetch latest release from GitHub."
            echo -e "$NC"
            exit 1
        fi

        wget "$latest_release" -O ziv-linux-amd64
        chmod +x ziv-linux-amd64

        # Generate SSL certificates
        openssl ecparam -genkey -name prime256v1 -out ca.key
        openssl req -new -x509 -days 36500 -key ca.key -out ca.crt -subj "/CN=bing.com"

        echo ""
        echo -e "\033[1;33mCreate Zivpn Passwords\033[0m"
        echo -e "\033[1;32mNote: Multiple Auth ( ex: a,b,c )\033[0m"
        echo -e "$YELLOW"
        read -p "Auth Str : " input_config
        echo -e "$NC"

        if [ -n "$input_config" ]; then
            IFS=',' read -r -a config <<< "$input_config"
            if [ ${#config[@]} -eq 1 ]; then
                config+=(${config[0]})
            fi
        else
            echo -e "$YELLOW"
            echo "Enter auth separated by commas"
            echo -e "$NC"
        fi

        echo "$input_config" > /root/zv/authusers
        auth_str=$(printf "\"%s\"," "${config[@]}" | sed 's/,$//')

        while true; do
            echo -e "$YELLOW"
            read -p "Remote UDP Port : " remote_udp_port
            echo -e "$NC"

            if is_number "$remote_udp_port" && [ "$remote_udp_port" -ge 1 ] && [ "$remote_udp_port" -le 65534 ]; then
                break
            else
                echo -e "$YELLOW"
                echo "Invalid input. Please enter a valid number between 1 and 65534."
                echo -e "$NC"
            fi
        done

        file_path="/root/zv/config.json"
        json_content='{"listen":"'"$(curl -s https://api.ipify.org)"':'"$remote_udp_port"'","cert":"/root/zv/ca.crt","key":"/root/zv/ca.key","auth":{"mode":"passwords","config":['"$auth_str"']}}'
        echo "$json_content" > "$file_path"

        if [ ! -e "$file_path" ]; then
            echo -e "$YELLOW"
            echo "Error: Unable to save the config.json file"
            echo -e "$NC"
            exit 1
        fi

        sudo debconf-set-selections <<< "iptables-persistent iptables-persistent/autosave_v4 boolean true"
        sudo debconf-set-selections <<< "iptables-persistent iptables-persistent/autosave_v6 boolean true"

        # Create Systemd Service
        cat <<EOF >/etc/systemd/system/ziv-server.service
[Unit]
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=/root
ExecStart=/root/zv/ziv-linux-amd64 server -c /root/zv/config.json
Restart=always
RestartSec=2
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

        systemctl enable ziv-server.service
        systemctl start ziv-server.service

        echo -e "$YELLOW"
        echo "    💚 UDP HYSTERIA INSTALLED SUCCESSFULLY 💚        "
        echo "      ╰┈➤💚 Telegram >>> t.me/Am_The_Last_Envoy    "
        echo -e "$NC"

        exit 0
        ;;
    2)
        echo -e "\033[1;33mUpdating Authentication Users\033[0m"
        
        rm -rf /root/zv/authusers
        echo -e "\033[1;32mMultiple Auth ( ex: a,b,c )\033[0m"
        echo -e "$YELLOW"
        read -p "Auth Str : " input_config
        echo -e "$NC"

        if [ -n "$input_config" ]; then
            IFS=',' read -r -a config <<< "$input_config"
            if [ ${#config[@]} -eq 1 ]; then
                config+=(${config[0]})
            fi
        else
            echo -e "$YELLOW"
            echo "Enter auth separated by commas"
            echo -e "$NC"
        fi

        echo "$input_config" > /root/zv/authusers
        auth_str=$(printf "\"%s\"," "${config[@]}" | sed 's/,$//')

        rm -rf /root/zv/config.json
        json_content='{"listen":"'"$(curl -s https://api.ipify.org)"':'"$remote_udp_port"'","cert":"/root/zv/ca.crt","key":"/root/zv/ca.key","auth":{"mode":"passwords","config":['"$auth_str"']}}'
        echo "$json_content" > "/root/zv/config.json"

        systemctl restart ziv-server.service

        echo -e "$YELLOW"
        echo "Authentication updated successfully!"
        echo -e "$NC"

        exit 0
        ;;
    3)
        echo -e "\033[1;32mActive Auth/Users:\033[0m"
        echo ""
        echo -e "\033[1;33m$(cat /root/zv/authusers | tr ',' '\n')\033[0m"
        echo ""
        read -p "Press any key to exit ↩" key
        exit 0
        ;;
    *)
        echo "Exiting..."
        exit 0
        ;;
esac
