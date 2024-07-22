# Superset Deployer

This repo makes deploying and updating [Superset](https://superset.apache.org/) easy by using bash scripts.

## Requirements
- This setup will use Minikube as a one node K8s instance, hence we recommend to use it on a VM with at least 2 (v)cores and 2GB of memory with at least 20GB free space. Check the current version of the Minikube [docs](https://minikube.sigs.k8s.io/docs/start) to check if requirements changed.
- We recommend to use the latest (LTS) version of Ubunut/Debian, other dirstors might work as well.
- Set up a domain name with your preferred Registrar to point to the IP you got for your server.

## Usage
1. Before you can use the script make sure you have an externally reachable IP address with firewall settings enabling ingress to 80 and 443 ports.
2. The script installs and updates [Caddy](https://caddyserver.com/) to create https. That requires a domain name already set up and pointing to the server.
3. Run the below script replacing the `<DOMAIN NAME>` with the one you configured previously.
```
git clone https://github.com/Corestad/superset-setup && cd superset-setup && ./init.sh -d <DOMAIN NAME>
```

> [!IMPORTANT]
> The init script makes use of some `sudo` commands (sparingly), so be prepared to provide the required password when prompted

> [!CAUTION]
> Check the Superset [Docs](https://superset.apache.org/docs/installation/kubernetes) and the Chart [doc](https://github.com/apache/superset/tree/master/helm/superset) regarding the current best practices to use their HELM chart.
> Specifically take into consideration that we provide a hardcoded `SECRET_KEY` in the values.yaml file which you might want to modify


## Update running installation.
1. `cd` into the directory where you pulled the repository
2. Run the updater script
```
./update.sh
```
