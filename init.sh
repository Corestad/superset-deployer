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


# 4, SUPERSET SETUP
helm repo add superset https://apache.github.io/superset;

# download values yaml for the chart
wget -O values.yaml https://raw.githubusercontent.com/apache/superset/master/helm/superset/values.yaml;
