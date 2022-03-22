#!/bin/bash
set -e

# start installation after cloud-init is finished
cloud-init status -w

##### INSTALLATION OF PACKAGES
sudo apt install -y apt-transport-https ca-certificates gnupg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
sudo apt update 
sudo apt purge -y man-db # takes long don't know why
sudo apt install -y google-cloud-sdk nfs-common wait-for-it iputils-ping

# Wait for the File store NFS before installing Velociraptor
wait-for-it ${file_share_ip_address}:111

# Create mount point NFS share
mkdir -p ${file_store_location}
sudo mount ${file_share_ip_address}:/${file_share_name} ${file_store_location}

# Exit if Velociraptor is already installed
#if [[ -f "/tmp/server.config.yaml" ]]; then
#  systemctl start velociraptor_server
#  exit 0
#fi

###### INSTALLATION OF VELOCIRAPTOR
cd /tmp
mkdir -p clients

wget -q https://github.com/Velocidex/velociraptor/releases/download/v${version}/velociraptor-v${version}-linux-amd64 -O velociraptor
chmod +x velociraptor
./velociraptor config generate -c server.config.yml --merge '{ "Client": { "server_urls": [ "https://${domain_name}/" ], "use_self_signed_ssl": false }, "API": { "hostname": "${hostname}", "bind_address": "0.0.0.0" }, "GUI": { "bind_address": "0.0.0.0", "bind_port": 8080, "base_path": "/gui", "use_plain_http": true, "public_url": "https://${domain_name}/" }, "Frontend": { "hostname": "${hostname}", "bind_address": "0.0.0.0", "use_plain_http": true, "public_url": "https://${domain_name}/", "bind_port": 8080 } }'> server.config.yaml
./velociraptor --config server.config.yaml debian server --output=velociraptor.deb
./velociraptor --config server.config.yaml config client > clients/client.config.yaml
sudo dpkg -i velociraptor.deb
sleep 1 # wait for Velociraptor is running
systemctl disable velociraptor_server
sudo -u velociraptor velociraptor --config server.config.yaml user add --role=administrator admin "${password}"

###### UPLOAD OF VELOCIRAPTOR CLIENTS
wget -q -P clients https://github.com/Velocidex/velociraptor/releases/download/v${version}/velociraptor-v${version}-darwin-arm64
wget -q -P clients https://github.com/Velocidex/velociraptor/releases/download/v${version}/velociraptor-v${version}-darwin-amd64
wget -q -P clients https://github.com/Velocidex/velociraptor/releases/download/v${version}/velociraptor-v${version}-linux-amd64
wget -q -P clients https://github.com/Velocidex/velociraptor/releases/download/v${version}/velociraptor-v${version}-linux-amd64-centos
wget -q -P clients https://github.com/Velocidex/velociraptor/releases/download/v${version}/velociraptor-v${version}-windows-amd64.exe
wget -q -P clients https://github.com/Velocidex/velociraptor/releases/download/v${version}/velociraptor-v${version}-windows-amd64.msi
gsutil -q -m cp -r clients/* ${bucket_uri}/velociraptor-clients