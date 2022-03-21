#!/bin/bash
set -e

# start after cloud-init is finished
cloud-init status -w

sudo apt update
sudo apt-get install -y nfs-common wait-for-it iputils-ping ca-certificates curl gnupg lsb-release

# Docker and Docker Compose installation
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt -y install docker-ce docker-ce-cli containerd.io
  
mkdir -p timesketch/{etc/timesketch/sigma/rules,upload,logs}

# Wait for the File store NFS before installing Velociraptor
wait-for-it ${file_share_ip_address}:111

# Create mount point NFS share
sudo mount ${file_share_ip_address}:/${file_share_name} timesketch/upload

# Timesketch configuration
GITHUB_BASE_URL="https://raw.githubusercontent.com/google/timesketch/${timesketch_version}"
curl -s $GITHUB_BASE_URL/data/tags.yaml > timesketch/etc/timesketch/tags.yaml
curl -s $GITHUB_BASE_URL/data/plaso.mappings > timesketch/etc/timesketch/plaso.mappings
curl -s $GITHUB_BASE_URL/data/generic.mappings > timesketch/etc/timesketch/generic.mappings
curl -s $GITHUB_BASE_URL/data/features.yaml > timesketch/etc/timesketch/features.yaml
curl -s $GITHUB_BASE_URL/data/ontology.yaml > timesketch/etc/timesketch/ontology.yaml
curl -s $GITHUB_BASE_URL/data/tags.yaml > timesketch/etc/timesketch/tags.yaml
curl -s $GITHUB_BASE_URL/data/intelligence_tag_metadata.yaml > timesketch/etc/timesketch/intelligence_tag_metadata.yaml
curl -s $GITHUB_BASE_URL/data/sigma_config.yaml > timesketch/etc/timesketch/sigma_config.yaml
curl -s $GITHUB_BASE_URL/data/sigma_blocklist.csv > timesketch/etc/timesketch/sigma_blocklist.csv
curl -s $GITHUB_BASE_URL/data/sigma/rules/lnx_susp_zmap.yml > timesketch/etc/timesketch/sigma/rules/lnx_susp_zmap.yml
#git clone https://github.com/Neo23x0/sigma timesketch/etc/timesketch/sigma

echo "${timesketch_configuration}" > timesketch/etc/timesketch/timesketch.conf

cd timesketch

cores=$(nproc --all)

sudo docker run --name timesketch-web -d \
  --restart no \
  -e NUM_WSGI_WORKERS=$((($cores*2) + 1)) \
  -v $(pwd)/etc/timesketch/:/etc/timesketch/ \
  -v $(pwd)/upload:/usr/share/timesketch/upload/ \
  -v $(pwd)/logs:/var/log/timesketch/ \
  --log-driver=gcplogs \
  -p 5000:5000 \
  us-docker.pkg.dev/osdfir-registry/timesketch/timesketch:latest \
  timesketch-web

sleep 1
sudo docker restart timesketch-web
sleep 1

sudo docker exec timesketch-web tsctl add_user -u admin -p ${timesketch_admin_password}