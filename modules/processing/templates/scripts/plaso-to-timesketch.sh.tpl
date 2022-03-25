#!/bin/bash

#  if error delete instance
#set -e

# start after cloud-init is finished
cloud-init status -w

sudo apt update
sudo apt install -y nfs-common wait-for-it iputils-ping ca-certificates curl gnupg lsb-release unzip 

# Docker installation
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get purge  -y man-db # takes long don't know why
sudo apt-get install -y docker-ce docker-ce-cli containerd.io google-cloud-sdk python3-pip

pip3 install timesketch-import-client

BUCKET_NAME=$(curl http://metadata/computeMetadata/v1/instance/attributes/bucket -H "Metadata-Flavor: Google")
OBJECT_NAME=$(curl http://metadata/computeMetadata/v1/instance/attributes/object -H "Metadata-Flavor: Google")

mkdir /data 
cd /data

# Download and extract hunt collection
gsutil -q cp "gs://$BUCKET_NAME/$OBJECT_NAME" timeline.zip
unzip -q timeline.zip -d timeline
SYSTEM=$(ls timeline/clients/)

docker run --entrypoint "" -v $(pwd):/data --name plaso log2timeline/plaso log2timeline.py --status_view none -q --storage_file /data/$SYSTEM.plaso  /data/timeline/clients/*/collections/*/uploads

# Upload timeline to bucket as back-up
gsutil -q cp $SYSTEM.plaso gs://$BUCKET_NAME/timelines/

timesketch_importer -q -u "admin" -p "${TIMESKETCH_PASSWORD}" --host ${TIMESKETCH_URL} --timeline_name $SYSTEM --sketch_id 1 $SYSTEM.plaso

# Delete instance
#gcloud logging write batch-execution "Hello world from $(hostname)."
gcp_zone=$(curl -H Metadata-Flavor:Google http://metadata.google.internal/computeMetadata/v1/instance/zone -s | cut -d/ -f4)
gcloud compute instances delete $(hostname) --zone $gcp_zone -q