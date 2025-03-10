#!/bin/bash
function log_step() {
  if [ "$VERBOSE" = true ]; then
    echo "### $1";
  fi
}

function set_safe() {
  set -Eeuo pipefail;
}

function set_unsafe() {
  set +Eeuo pipefail;
}

set_safe;

# init opts variables
DOMAIN_NAME='';
VERBOSE=false;
POSITIONAL_ARGS=();
SKIP_STEP=false;

while [[ $# -gt 0 ]]; do
  case $1 in
    -d|--domain)
      DOMAIN_NAME="$2"
      shift # past argument
      shift # past value
      ;;
    -v|--verbose)
      VERBOSE=true;
      shift # past argument
      ;;
    -ss|--skip-stet)
      if [ "$SKIP_STEP" = false ]; then
        SKIP_STEP="$2";
      else
        SKIP_STEP="$SKIP_STEP,$2";
      fi
      shift
      shift
      ;;
    -h|--help)
      echo "Usage: ./init.sh -d <domain_name> [-v|--verbose] [-ss|--skip-step <step_name>]";
      echo "OPTIONS:";
      echo "  -d, --domain <domain_name>   Domain name to use for the setup";
      echo "  -v, --verbose                Enable verbose mode";
      echo "  -ss, --skip-step <step_name> Skip a step in the setup process";
      echo "                               Possible values:";
      echo "                                                 - initial_update";
      echo "                                                 - docker_engine_install";
      echo "                                                 - docker_postinstall";
      echo "                                                 - minikube_install";
      echo "                                                 - kubectl_install";
      echo "                                                 - superset_setup";
      echo "                                                 - caddy_setup";
      exit 0;
      ;;
    -*)
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

initial_update() {
  # 1, INITIAL UPDATE and Setup
  log_step "Initial update";
  sudo apt -qq update;
  sudo apt -qq upgrade -y;

  log_step "Install dependencies";
  sudo apt -qq install -y debian-keyring debian-archive-keyring apt-transport-https ca-certificates curl apt-transport-https gnupg;
}

docker_engine_install() {

  # 2, DOCKER ENGINE INSTALL
  # remove old docker engine packages
  log_step "Remove old docker engine packages";
  for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt remove $pkg; done;

  # Add Docker's official GPG key:
  log_step "Installing Docker engine";
  sudo install -m 0755 -d /etc/apt/keyrings;
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc;
  sudo chmod a+r /etc/apt/keyrings/docker.asc;

  # Add the repository to Apt sources:
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt -qq update;
  sudo apt -qq install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin --yes;

  log_step "Docker engine installed";
}

docker_postinstall() {
  # docker postinstall
  log_step "Docker postinstall";

  set_unsafe; # error returned when docker group already exists
  sudo groupadd docker | true;
  set_safe;

  sudo usermod -aG docker "$USER";

  # autostart docker on system startup
  log_step "Enable docker service";
  sudo systemctl enable docker.service;
  sudo systemctl enable containerd.service;

  # newgrp starts a subshell that never returns -> send the commands to the subshell
  /usr/bin/newgrp docker <<EONG
  ./init.sh -d "$DOMAIN_NAME" -v -ss initial_update -ss docker_engine_install -ss docker_postinstall 
EONG

}

minikube_install() {
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

  log_step "Add minikube to the system startup";
  CRONJOB_FILE="cronjobs";
  CRONJOB_ITEM="@reboot sleep 10 && minikube start";

  touch "$CRONJOB_FILE";
  set_unsafe;
  (crontab -l > "$CRONJOB_FILE") | true;
  set_safe;

  if grep -xq "$CRONJOB_ITEM" "${CRONJOB_FILE}"
  then
    rm "$CRONJOB_FILE";
  else
    echo "$CRONJOB_ITEM" >> "$CRONJOB_FILE";
    crontab "$CRONJOB_FILE";
    rm "$CRONJOB_FILE";
  fi
}

kubectl_install() {
  # install kubectl
  log_step "Install kubectl";
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg;
  sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg; # allow unprivileged APT programs to read this keyring
  # This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
  echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list;
  sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list;   # helps tools such as command-not-found to work correctly
  sudo apt -qq update;
  sudo apt -qq install -y kubectl;

  # Install bash autocompletion for kubectl
  COMPLETEION_STRING='complete -o default -F __start_kubectl'
  if grep -xq "$COMPLETEION_STRING" ~/.bashrc
  then
    log_step "kubectl autocomplete already installed";
  else
    log_step "Install kubectl autocomplete";

    source /usr/share/bash-completion/bash_completion;
    echo 'source <(kubectl completion bash)' >>~/.bashrc
    echo 'alias k=kubectl' >>~/.bashrc;
    echo "$COMPLETEION_STRING" >>~/.bashrc;
    # shellcheck source="$HOME/.bashrc"
    source "$HOME/.bashrc";
    log_step "kubectl autocomplete already installed";
  fi
}

superset_setup() {
  # 4, SUPERSET SETUP
  log_step "Install Superset HELM chart";
  helm repo add superset https://apache.github.io/superset;

  # apply custom values to chart and install it
  log_step "Install Superset chart with custom values";
  helm upgrade --install --values --wait --timeout 10m ./superset/helm/superset/values.yaml superset superset/superset;
}

caddy_setup() {
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
  exposed_service_url=$(minikube service superset --url);
  sed -e "s,MINIKUBE_URL,$exposed_service_url,g" -e "s,DOMAIN_NAME,$DOMAIN_NAME,g" ./Caddyfile > ./tmp_caddyfile; # custom delimeter to sed since we are inserting url taht contains /
  sudo mv ./tmp_caddyfile /etc/caddy/Caddyfile;
  caddy reload -c /etc/caddy/Caddyfile;
}

main() {
  if [[ $SKIP_STEP != *"initial_update"* ]]; then
    initial_update;
  fi

  if [[ $SKIP_STEP != *"docker_engine_instal"* ]]; then
    docker_engine_install;
  fi

  if [[ $SKIP_STEP != *"docker_postinstall"* ]]; then
    docker_postinstall "$@";
  fi

  if [[ $SKIP_STEP != *"minikube_install"* ]]; then
    minikube_install;
  fi

  if [[ $SKIP_STEP != *"kubectl_install"* ]]; then
    kubectl_install;
  fi

  if [[ $SKIP_STEP != *"superset_setup"* ]]; then
    superset_setup;
  fi

  if [[ $SKIP_STEP != *"caddy_setup"* ]]; then
    caddy_setup;
  fi
}

main "$@";
