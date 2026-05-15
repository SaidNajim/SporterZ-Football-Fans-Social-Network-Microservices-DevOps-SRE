#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "SporterZ Kubernetes Deployment (Simplified)"
echo "=========================================="

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DEPLOY_KAFKA="${DEPLOY_KAFKA:-true}"
DEPLOY_MESSAGING="${DEPLOY_MESSAGING:-true}"
DEPLOY_ENVOY_WAF="${DEPLOY_ENVOY_WAF:-true}"
DEPLOY_KYVERNO="${DEPLOY_KYVERNO:-true}"
DEPLOY_ARGOCD="${DEPLOY_ARGOCD:-true}"
ENVOY_INSTALL_URL="${ENVOY_INSTALL_URL:-https://github.com/envoyproxy/gateway/releases/download/v1.2.0/install.yaml}"
ENVOY_GATEWAY_API_URL="${ENVOY_GATEWAY_API_URL:-https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml}"
ENVOY_NODEPORT="${ENVOY_NODEPORT:-30080}"
KYVERNO_NAMESPACE="${KYVERNO_NAMESPACE:-kyverno}"
KYVERNO_INSTALL_URL="${KYVERNO_INSTALL_URL:-https://github.com/kyverno/kyverno/releases/latest/download/install.yaml}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_INSTALL_URL="${ARGOCD_INSTALL_URL:-https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml}"

wait_rollout() {
  local deployment="$1"
  local namespace="${2:-default}"
  kubectl rollout status "deployment/${deployment}" -n "${namespace}" --timeout=180s || true
}

configure_envoy_nodeport() {
  local svc
  local merge_patch_file
  local json_patch_file
  svc="$(kubectl get svc -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=sporterz-gateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [[ -z "${svc}" ]]; then
    echo -e "${YELLOW}Envoy proxy service not found yet, retrying...${NC}"
    sleep 5
    svc="$(kubectl get svc -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=sporterz-gateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  fi
  if [[ -z "${svc}" ]]; then
    echo "ERROR: could not find Envoy proxy service for gateway 'sporterz-gateway'."
    exit 1
  fi

  merge_patch_file="$(mktemp)"
  json_patch_file="$(mktemp)"
  printf '%s' '{"spec":{"type":"NodePort","externalTrafficPolicy":"Cluster"}}' > "${merge_patch_file}"
  printf '%s' "[{\"op\":\"replace\",\"path\":\"/spec/ports/0/nodePort\",\"value\":${ENVOY_NODEPORT}}]" > "${json_patch_file}"
  kubectl patch svc -n envoy-gateway-system "${svc}" --type=merge --patch-file "${merge_patch_file}" >/dev/null
  kubectl patch svc -n envoy-gateway-system "${svc}" --type=json --patch-file "${json_patch_file}" >/dev/null
  rm -f "${merge_patch_file}" "${json_patch_file}"

  echo -e "${GREEN}Envoy service ${svc} is pinned to NodePort ${ENVOY_NODEPORT}${NC}"
}

bootstrap_argocd() {
  if [[ "${DEPLOY_KAFKA}" != "true" || "${DEPLOY_MESSAGING}" != "true" || "${DEPLOY_ENVOY_WAF}" != "true" ]]; then
    echo -e "${YELLOW}Note: Argo CD ApplicationSet manages the full stack manifests and may reconcile resources even when DEPLOY_* toggles are set to false.${NC}"
  fi

  echo -e "${YELLOW}Installing/updating Argo CD in namespace ${ARGOCD_NAMESPACE}...${NC}"
  kubectl create namespace "${ARGOCD_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  kubectl apply -n "${ARGOCD_NAMESPACE}" --server-side --force-conflicts -f "${ARGOCD_INSTALL_URL}" >/dev/null

  kubectl get crd applications.argoproj.io >/dev/null
  kubectl get crd applicationsets.argoproj.io >/dev/null
  kubectl get crd appprojects.argoproj.io >/dev/null

  kubectl rollout status deployment/argocd-server -n "${ARGOCD_NAMESPACE}" --timeout=240s || true
  kubectl rollout status statefulset/argocd-application-controller -n "${ARGOCD_NAMESPACE}" --timeout=240s || true
  kubectl rollout status deployment/argocd-applicationset-controller -n "${ARGOCD_NAMESPACE}" --timeout=240s || true

  echo -e "${YELLOW}Installing Argo CD Image Updater...${NC}"
  kubectl apply -n "${ARGOCD_NAMESPACE}" -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml >/dev/null
  kubectl rollout status deployment/argocd-image-updater -n "${ARGOCD_NAMESPACE}" --timeout=120s || true

  echo -e "${YELLOW}Applying Argo CD AppProject + ApplicationSet...${NC}"
  kubectl apply -f project-sporterz.yaml
  kubectl apply -f applicationset-sporterz.yaml
}

bootstrap_kyverno() {
  echo -e "${YELLOW}Installing/updating Kyverno in namespace ${KYVERNO_NAMESPACE}...${NC}"
  kubectl create namespace "${KYVERNO_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

  if ! kubectl get crd clusterpolicies.kyverno.io >/dev/null 2>&1 || \
     ! kubectl get deployment -n "${KYVERNO_NAMESPACE}" kyverno-admission-controller >/dev/null 2>&1; then
    kubectl apply -f "${KYVERNO_INSTALL_URL}" >/dev/null
  fi

  kubectl get crd clusterpolicies.kyverno.io >/dev/null
  kubectl rollout status deployment/kyverno-admission-controller -n "${KYVERNO_NAMESPACE}" --timeout=240s || true

  echo -e "${YELLOW}Kyverno policy is managed by ArgoCD (security-overlay)...${NC}"
}

echo -e "${YELLOW}Checking kind cluster...${NC}"
if ! kind get clusters | grep -q "^sporterz$"; then
  echo -e "${YELLOW}Creating kind cluster 'sporterz'...${NC}"
  kind create cluster --name sporterz --config cluster-config.yaml
else
  echo -e "${GREEN}kind cluster 'sporterz' already exists${NC}"
fi

echo -e "${YELLOW}Setting kubectl context to kind-sporterz...${NC}"
kubectl config use-context kind-sporterz

if [[ "${DEPLOY_KAFKA}" == "true" ]]; then
  echo -e "${YELLOW}Checking Strimzi Kafka operator...${NC}"
  kubectl create namespace kafka --dry-run=client -o yaml | kubectl apply -f -
  if ! kubectl get deployment -n kafka strimzi-cluster-operator >/dev/null 2>&1; then
    echo -e "${YELLOW}Installing Strimzi operator...${NC}"
    kubectl apply -f "https://strimzi.io/install/latest?namespace=kafka" -n kafka
  fi
  wait_rollout "strimzi-cluster-operator" "kafka"

  echo -e "${YELLOW}Applying Kafka single-node cluster...${NC}"
  kubectl apply -f kafka-single-node.yaml
else
  echo -e "${YELLOW}Skipping Kafka install (DEPLOY_KAFKA=${DEPLOY_KAFKA})${NC}"
fi

echo -e "${YELLOW}Applying application services...${NC}"
kubectl apply -f auth-service.yaml
kubectl apply -f posts-service.yaml
kubectl apply -f match-service.yaml
if [[ "${DEPLOY_MESSAGING}" == "true" ]]; then
  kubectl apply -f messaging-service.yaml
else
  echo -e "${YELLOW}Skipping messaging service (DEPLOY_MESSAGING=${DEPLOY_MESSAGING})${NC}"
fi
kubectl apply -f api-gateway.yaml
kubectl apply -f frontend.yaml

if [[ "${DEPLOY_ENVOY_WAF}" == "true" ]]; then
  echo -e "${YELLOW}Installing Gateway API and Envoy Gateway...${NC}"
  if ! kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1; then
    kubectl apply -f "${ENVOY_GATEWAY_API_URL}" >/dev/null
  fi
  if ! kubectl get crd envoyextensionpolicies.gateway.envoyproxy.io >/dev/null 2>&1 || \
     ! kubectl get deployment -n envoy-gateway-system envoy-gateway >/dev/null 2>&1; then
    kubectl apply -f "${ENVOY_INSTALL_URL}" >/dev/null
  fi
  kubectl get crd gateways.gateway.networking.k8s.io >/dev/null
  kubectl get crd envoyextensionpolicies.gateway.envoyproxy.io >/dev/null
  wait_rollout "envoy-gateway" "envoy-gateway-system"

  echo -e "${YELLOW}Applying Gateway route + Coraza WAF policy...${NC}"
  kubectl apply -f envoy-gateway.yaml
  kubectl apply -f envoy-extension-policy.yaml
  configure_envoy_nodeport
else
  echo -e "${YELLOW}Skipping Envoy/WAF install (DEPLOY_ENVOY_WAF=${DEPLOY_ENVOY_WAF})${NC}"
fi

if [[ "${DEPLOY_KYVERNO}" == "true" ]]; then
  bootstrap_kyverno
else
  echo -e "${YELLOW}Skipping Kyverno install (DEPLOY_KYVERNO=${DEPLOY_KYVERNO})${NC}"
fi

echo -e "${YELLOW}Applying monitoring stack...${NC}"
kubectl apply -f prometheus-config.yaml
kubectl apply -f prometheus.yaml
kubectl apply -f grafana.yaml

if [[ "${DEPLOY_ARGOCD}" == "true" ]]; then
  bootstrap_argocd
else
  echo -e "${YELLOW}Skipping Argo CD bootstrap (DEPLOY_ARGOCD=${DEPLOY_ARGOCD})${NC}"
fi

echo -e "${YELLOW}Waiting for primary deployments...${NC}"
wait_rollout "auth-service"
wait_rollout "posts-service"
wait_rollout "match-service"
if [[ "${DEPLOY_MESSAGING}" == "true" ]]; then
  wait_rollout "messaging-service"
fi
wait_rollout "api-gateway"
wait_rollout "frontend"

echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}Deployment Complete${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
if [[ "${DEPLOY_ENVOY_WAF}" == "true" ]]; then
  echo "Main entrypoint (through Envoy + WAF):"
else
  echo "Main entrypoint (direct to API gateway):"
fi
echo "  - http://localhost/"
echo ""
echo "Useful checks:"
echo "  - kubectl get svc -n envoy-gateway-system"
echo "  - kubectl get envoyextensionpolicy coraza-waf-poc"
echo "  - kubectl get clusterpolicy verify-signed-sporterz-images"
echo "  - kubectl get pods -n ${KYVERNO_NAMESPACE}"
echo "  - kubectl get pods"
echo "  - kubectl get applicationsets -n argocd"
echo "  - kubectl get applications -n argocd"
echo "  - kubectl logs -l app=api-gateway --tail=100"
echo "  - DEPLOY_KAFKA=true DEPLOY_MESSAGING=true DEPLOY_ENVOY_WAF=true DEPLOY_KYVERNO=true DEPLOY_ARGOCD=true ./deploy.sh"
echo ""
echo "Monitoring:"
echo "  - Prometheus: kubectl port-forward svc/prometheus 9090:9090"
echo "  - Grafana: kubectl port-forward svc/grafana 3000:3000"
