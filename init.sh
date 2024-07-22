#!/bin/bash
set -Eeuo pipefail;

function log_step() {
  echo "### $1";
}

# init opts variables
DOMAIN_NAME='';
POSITIONAL_ARGS=();

while [[ $# -gt 0 ]]; do
  case $1 in
    -d|--domain)
      DOMAIN_NAME="$2"
      shift # past argument
      shift # past value
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done



if [ -z "$DOMAIN_NAME" ]; then
  echo "Domain name is required";
  echo "Usage: ./init.sh -d <domain_name>"
  exit 1;
fi

# 1, INITIAL UPDATE and Setup
log_step "Initial update";
sudo apt -qq update;
sudo apt -qq upgrade -y;

log_step "Install dependencies";
sudo apt -qq install -y debian-keyring debian-archive-keyring apt-transport-https ca-certificates curl apt-transport-https gnupg;

# 2, DOCKER ENGINE INSTALL
# remove old docker engine packages
log_step "Remove old docker engine packages";
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt remove $pkg; done;
exit_code=$?

if [ $exit_code -ne 0 ]; then
  echo "Failed to remove old docker engine packages (if they ever existed)";
fi
# Add Docker's official GPG key:
log_step "Installing Docker engine";
sudo install -m 0755 -d /etc/apt/keyrings;
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc;
sudo chmod a+r /etc/apt/keyrings/docker.asc;

sudo apt -qq install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin --yes;

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt -qq update;
log_step "Docker engine installed";

# docker postinstall
log_step "Docker postinstall";
sudo groupadd docker;
sudo usermod -aG docker "$USER";
newgrp docker;

# autostart docker on system startup
log_step "Enable docker service";
sudo systemctl enable docker.service;
sudo systemctl enable containerd.service;

# 3, MINIKUBE INSTALL
log_step "Install minikube";
curl -LOs https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb;
sudo dpkg -i minikube_latest_amd64.deb;

minikube start;
# cleanup
rm -rf minikube_latest_amd64.deb;

# install HELM
log_step "Install helm";
curl -s https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt -qq update;
sudo apt -qq install helm --yes;

# install kubectl
log_step "Install kubectl";
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg;
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg; # allow unprivileged APT programs to read this keyring
# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list;
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list;   # helps tools such as command-not-found to work correctly
sudo apt -qq update;
sudo apt -qq install -y kubectl;

log_step "Install kubectl autocomplete";
source /usr/share/bash-completion/bash_completion;
echo 'alias k=kubectl' >>~/.bashrc;
echo 'complete -o default -F __start_kubectl k' >>~/.bashrc;
# shellcheck source="$HOME/.bashrc"
source "$HOME/.bashrc";


# 4, SUPERSET SETUP
log_step "Install Superset HELM chart";
helm repo add superset https://apache.github.io/superset;

# apply custom values to chart and install it
log_step "Install Superset chart with custom values";
helm upgrade --install --values ./superset/helm/superset/values.yaml superset superset/superset;


# 5, Install Caddy
log_step "Install Caddy";
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg;
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list;
sudo apt -qq update;
sudo apt -qq install caddy;

# add caddy to the system startup
sudo systemctl enable caddy-api.service caddy-api.service;


# 6, get minikube IP of the exposed service
log_step "Set up Caddyfile"
minikue service superset --url
exposed_service_url=$?
sed -i -e "s/MINIKUBE_URL/$exposed_service_url" -e "s/DOMAIN_NAME/$DOMAIN_NAME" ./Caddyfile >> /etc/caddy/Caddyfile;
caddy reload -c /etc/caddy/Caddyfile;

# TODO: add minikube to the system startup

