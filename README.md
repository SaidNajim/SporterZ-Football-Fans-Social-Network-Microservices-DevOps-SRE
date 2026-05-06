# SporterZ DevOps/SRE 

<p align="leftS">
  <img src="https://i.ibb.co/vj7xmFZ/logo.png" alt="SporterZ logo" width="120">
</p>

## Contributors

- [Said NAJIM](https://www.linkedin.com/in/saidnajim/)
- [Ilyas ABDELLAOUI](https://www.linkedin.com/in/ilyas-abdellaoui/)
- [Mohammed-Yassine BOUMEHDI](https://www.linkedin.com/in/myassineboumehdi/)
- [Adnane MANDILI](https://www.linkedin.com/in/adnane-mandili-12997b251/)

## What This Repository Contains

- Spring Boot microservices:
  - `auth-service`
  - `posts-service`
  - `match-service`
  - `messaging-service`
  - `api-gateway`
- Kubernetes manifests and scripts in `k8s/`
- Monitoring stack:
  - Prometheus (`k8s/prometheus.yaml`, `k8s/prometheus-config.yaml`)
  - Grafana (`k8s/grafana.yaml`)
- Gateway and security:
  - Envoy Gateway (`k8s/envoy-gateway.yaml`)
  - Coraza WAF policy (`k8s/envoy-extension-policy.yaml`)
- Argo CD GitOps bootstrap:
  - Project + ApplicationSet
- Docker image automation script: `build-and-push.sh`

---

## Prerequisites

Install these before running anything:

- Docker Desktop (running)
- `kubectl`
- `kind`
- Java 17
- Maven 3.9+
- Bash shell
  - Linux/macOS: default shell is fine
  - Windows: use Git Bash or WSL for `*.sh` scripts

Also make sure:

- Docker Hub access is available (`docker login`)
- Port `80` on your host is free (Kind maps host `80` to cluster NodePort `30080`)

---

## Quick Start

From repository root:

```bash
# 1) Build and push backend images (includes Maven build)
./build-and-push.sh --build

# 2) Deploy everything (cluster + services + gateway + monitoring + Argo CD)
cd k8s
./deploy.sh

# 3) Validate cluster
./status.sh
```

Main app entrypoint:

- [http://localhost/](http://localhost/)

---

## Detailed End-to-End Guide

## 1) Clone and open repository

```bash
git clone <YOUR_REPO_URL>
cd SporterZ-DevOps-SRE
```

## 2) Build and push Docker images

Script used: `build-and-push.sh`

```bash
# Uses existing JARs in each service target/ directory
./build-and-push.sh

# Builds JARs first (recommended)
./build-and-push.sh --build
```

What this script currently builds/pushes:

- `mrxmoon/sporterz-auth-service:latest`
- `mrxmoon/sporterz-posts-service:latest`
- `mrxmoon/sporterz-match-service:latest`
- `mrxmoon/sporterz-messaging-service:latest`
- `mrxmoon/sporterz-api-gateway:latest`

Notes:

- The script logs into Docker Hub interactively.
- `frontend` image is referenced in Kubernetes as `mrxmoon/sporterz-frontend:latest`, but is not built by `build-and-push.sh`.
- If you change frontend code, build/push that image separately or update `k8s/frontend.yaml` to your own image.

## 3) Deploy to Kind Kubernetes

Script used: `k8s/deploy.sh`

```bash
cd k8s
./deploy.sh
```

What `deploy.sh` does:

1. Creates Kind cluster `sporterz` if missing (`cluster-config.yaml`)
2. Switches context to `kind-sporterz`
3. Optionally installs Strimzi and deploys Kafka (`kafka-single-node.yaml`)
4. Deploys microservices
5. Optionally installs Gateway API + Envoy Gateway
6. Applies Envoy Gateway route and Coraza WAF policy
7. Pins Envoy data plane service to NodePort `30080`
8. Deploys Prometheus + Grafana
9. Installs/updates Argo CD in `argocd` namespace
10. Applies `AppProject` + `ApplicationSet` linked to this repository
11. Waits for main workloads rollout

### Deployment toggles

You can enable/disable parts with environment variables:

- `DEPLOY_KAFKA=true|false`
- `DEPLOY_MESSAGING=true|false`
- `DEPLOY_ENVOY_WAF=true|false`
- `DEPLOY_ARGOCD=true|false`
- `ENVOY_NODEPORT=<port>` (default `30080`)

Examples:

```bash
# Full stack (default behavior)
DEPLOY_KAFKA=true DEPLOY_MESSAGING=true DEPLOY_ENVOY_WAF=true DEPLOY_ARGOCD=true ./deploy.sh

# Without Kafka + messaging
DEPLOY_KAFKA=false DEPLOY_MESSAGING=false ./deploy.sh
```

PowerShell equivalent (when launching bash from PowerShell):

```powershell
$env:DEPLOY_KAFKA="true"
$env:DEPLOY_MESSAGING="true"
$env:DEPLOY_ENVOY_WAF="true"
$env:DEPLOY_ARGOCD="true"
bash ./deploy.sh
```

### Argo CD install command used by `deploy.sh`

```bash
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### Argo CD ApplicationSet (GitOps source)

- Repository URL: `https://github.com/SaidNajim/SporterZ-Football-Fans-Social-Network-Microservices-DevOps-SRE`
- ApplicationSet manifest: `applicationset-sporterz.yaml`
- Generated applications target selected manifests under `k8s/*.yaml`
- When `DEPLOY_ARGOCD=true`, Argo CD reconciliation can re-apply managed resources even if some `DEPLOY_*` toggles are `false` in `deploy.sh`

## 4) Verify deployment

From `k8s/`:

```bash
./status.sh
```

Or direct kubectl checks:

```bash
kubectl get pods
kubectl get svc
kubectl get gateway sporterz-gateway
kubectl get httproute api-gateway-route
kubectl get envoyextensionpolicy coraza-waf-poc
kubectl get applicationsets -n argocd
kubectl get applications -n argocd
```

---

## Accessing Services

## Main traffic path

- User -> `http://localhost/`
- Kind host port `80` -> NodePort `30080`
- Envoy Gateway -> API Gateway (`api-gateway:8888`) -> backend services

## Monitoring

Prometheus:

```bash
kubectl port-forward svc/prometheus 9090:9090
```

- URL: [http://localhost:9090](http://localhost:9090)

Grafana:

```bash
kubectl port-forward svc/grafana 3000:3000
```

- URL: [http://localhost:3000](http://localhost:3000)
- Default credentials:
  - User: `admin`
  - Password: `admin`

Prometheus datasource URL in Grafana (inside cluster):

- `http://prometheus:9090`

---

## Logs and Troubleshooting

## Follow logs quickly

From `k8s/`:

```bash
./logs.sh auth-service
./logs.sh posts-service
./logs.sh match-service
./logs.sh messaging-service
./logs.sh api-gateway
./logs.sh frontend
./logs.sh kafka
```

## Common kubectl debug commands

```bash
kubectl get events --sort-by='.lastTimestamp'
kubectl describe pod <pod-name>
kubectl logs -l app=api-gateway --tail=200
kubectl logs -l app=messaging-service --tail=200
```

## Frequent issues

- Port 80 already in use:
  - Free the host port or change mapping in `k8s/cluster-config.yaml` and related access instructions.
- `ImagePullBackOff`:
  - Verify images exist and are pushed to the registry used in manifests.
- Envoy service not found/patched:
  - Wait a bit and re-run `./deploy.sh`; CRDs/controller may still be initializing.
- Kafka not ready yet:
  - Strimzi resources can take time; check `kubectl get pods -n kafka`.
- Wrong kubectl context:
  - Run `kubectl config use-context kind-sporterz`.

---

## Teardown

Script used: `k8s/teardown.sh`

```bash
cd k8s
./teardown.sh
```

This script interactively asks whether to:

- delete Kubernetes resources
- delete Kind cluster `sporterz`

---

## Kubernetes Manifests Map

Core services:

- `k8s/auth-service.yaml`
- `k8s/posts-service.yaml`
- `k8s/match-service.yaml`
- `k8s/messaging-service.yaml`
- `k8s/api-gateway.yaml`
- `k8s/frontend.yaml`

Gateway + WAF:

- `k8s/envoy-gateway.yaml`
- `k8s/envoy-extension-policy.yaml`

Kafka:

- `k8s/kafka-single-node.yaml`

Monitoring:

- `k8s/prometheus-config.yaml`
- `k8s/prometheus.yaml`
- `k8s/grafana.yaml`

Argo CD:

- `k8s/project-sporterz.yaml`
- `k8s/applicationset-sporterz.yaml`

Cluster config:

- `k8s/cluster-config.yaml`

Operational scripts:

- `build-and-push.sh`
- `k8s/deploy.sh`
- `k8s/status.sh`
- `k8s/logs.sh`
- `k8s/teardown.sh`

---

## One-Page Command Cheat Sheet

```bash
# From repo root
./build-and-push.sh --build

cd k8s
./deploy.sh
./status.sh

# Argo CD checks
kubectl get applicationsets -n argocd
kubectl get applications -n argocd

# App
start http://localhost/   # Windows

# Monitoring
kubectl port-forward svc/prometheus 9090:9090
kubectl port-forward svc/grafana 3000:3000

# Logs
./logs.sh api-gateway

# Teardown
./teardown.sh
```

---

## Demo Screenshots

### Build and pipeline

![Build System](https://i.ibb.co/tQyk8DY/build.png)
![GitHub/GitLab Sync](https://i.ibb.co/r4FvXF3/sync.png)
![CI/CD](https://i.ibb.co/GHPftyz/CI-CD.jpg)

### Gateway and security

![API Gateway](https://i.ibb.co/TmwBnhq/api-Gateway.png)
![JWT](https://i.ibb.co/h2yKsqM/jwt.png)
![Password Hashing](https://i.ibb.co/8780RwF/passHash.png)

### Product and UI

![Application Mockup](https://i.ibb.co/R6bqMR0/HOME.png)
![Multilingual](https://i.ibb.co/MfZbLpn/multi-Lung.png)

### Observability and deployment

![Prometheus](https://i.ibb.co/CBnRdxV/prometheus.png)
![Grafana Dashboard](https://i.ibb.co/RDtYdbS/grafana.png)
![Docker Hub](https://i.ibb.co/HTBjcb9/dockerhub.png)
![Kubernetes](https://i.ibb.co/whpsKdP/k8s.png)
