# 1, INITIAL UPDATE
sudo apt update;
sudo apt upgrade -y;

# 2, DOCKER ENGINE INSTALL
# remove old docker engine packages
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done;


# Add Docker's official GPG key:
sudo apt update;
sudo apt install ca-certificates curl --yes;
sudo install -m 0755 -d /etc/apt/keyrings;
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc;
sudo chmod a+r /etc/apt/keyrings/docker.asc;

sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin --yes;

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update;

# docker postinstall
sudo groupadd docker;
sudo usermod -aG docker $USER;
newgrp docker;

# autostart docker on system startup
sudo systemctl enable docker.service;
sudo systemctl enable containerd.service;

# 3, MINIKUBE INSTALL
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb;
sudo dpkg -i minikube_latest_amd64.deb;

minikube start;

# install HELM
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt install apt-transport-https --yes;
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt update;
sudo apt install helm --yes;

# install kubectl
sudo apt install -y apt-transport-https ca-certificates curl gnupg;
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg;
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg; # allow unprivileged APT programs to read this keyring
# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list;
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list;   # helps tools such as command-not-found to work correctly
sudo apt update;
sudo apt install -y kubectl;

# 4, SUPERSET SETUP
helm repo add superset https://apache.github.io/superset;

# download values yaml for the chart
wget -O values.yaml https://raw.githubusercontent.com/Corestad/superset-setup/main/superset/helm/superset/values.yaml;

# apply custom values to chart and install it
helm upgrade --install --values values.yaml superset superset/superset;
