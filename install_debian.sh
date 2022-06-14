#!/usr/bin/env bash

echo This script will automatically setup NGINX with LetsEncrypt SSL.
read -p "Please enter the domain name you wish to setup with the NGINX configuration: " dname
read -p "Please specify what port to run the Qroxy service on (defaults to 8008): " port
cd ~
echo ---
echo Installing common dependencies
echo ---
apt install -y git software-properties-common tmux gpg gpg-agent dirmngr nginx certbot
echo ---
echo Installing python dependencies
echo ---
add-apt-repository ppa:deadsnakes/ppa
apt install -y python3.9 python3-pip python3-certbot-nginx
echo ---
echo Configuring NGINX with LetsEncrypt SSL Certs
echo --
if [ -n $port ]; then
port=8008 
fi
echo Port is $port
cat << EOF > /etc/nginx/conf.d/$dname.conf
server {
    server_name $dname;
    location / {
        proxy_pass http://localhost:$port;
    }
}
EOF
echo NGINX Configuration stored in /etc/nginx/conf.d/$dname.conf
nginx -t && nginx -s reload
echo >> Setting up LetsEncrypt. You will need to enter any requested information and accept the TOS.
certbot --nginx -d $dname
if crontab -l | grep -Fxq '0 12 * * * /usr/bin/certbot renew --quiet'; then
echo LetsEncrypt Autorenew cron found. Skipping.
else
(crontab -l ; echo '
# Lets Encrypt SSL Autorenew
0 12 * * * /usr/bin/certbot renew --quiet
') | crontab -
echo LetsEncrypt Autorenew cron added.
fi
echo ---
echo Setting up Qroxy in /var/qroxy
echo ---
mkdir /var/qroxy
git clone https://github.com/techanon/qroxy.git /var/qroxy
git config pull.ff only
cd /var/qroxy
cat << EOF > settings.ini
[server]
host=localhost
port=$port
EOF
python3 -m pip install -U yt-dlp aiohttp
echo ---
echo You may now run the Qroxy service via 'python3 qroxy.py' and access it via https://$dname/.
echo Try it out with this sample URL: https://$dname/?url=https://www.youtube.com/watch?v=wpV-gGA4PSk
echo It is recommended to use a tool like tmux to run the service without needing to be connected to the terminal.
echo You can do so with this command: tmux new-session -d -s qroxy_service \; send-keys "python3 /var/qroxy/qroxy.py" Enter