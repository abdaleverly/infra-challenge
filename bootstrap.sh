#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

sudo apt update
sudo apt install -y python3-pip awscli jq wget ruby

# codedeploy
export REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r ".region")
cd /tmp/
wget https://aws-codedeploy-${REGION}.s3.amazonaws.com/latest/install
chmod +x ./install
if ./install auto > /tmp/logfile; then
  echo "Instalation completed"
  exit 0
else
  echo "Instalation script failed, please investigate"
  rm -f /tmp/install
  exit 1
fi
service codedeploy-agent status