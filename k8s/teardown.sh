#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
KYVERNO_NAMESPACE="${KYVERNO_NAMESPACE:-kyverno}"
KYVERNO_INSTALL_URL="${KYVERNO_INSTALL_URL:-https://github.com/kyverno/kyverno/releases/latest/download/install.yaml}"

echo "=========================================="
echo "SporterZ Teardown Script"
echo "=========================================="

read -p "Delete Kubernetes resources? (y/N): " confirm

if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    echo "Deleting resources..."

    kubectl delete -f applicationset-sporterz.yaml --ignore-not-found=true
    kubectl delete -f project-sporterz.yaml --ignore-not-found=true
    kubectl delete -f frontend.yaml --ignore-not-found=true
    kubectl delete -f api-gateway.yaml --ignore-not-found=true
    kubectl delete -f messaging-service.yaml --ignore-not-found=true
    kubectl delete -f match-service.yaml --ignore-not-found=true
    kubectl delete -f posts-service.yaml --ignore-not-found=true
    kubectl delete -f auth-service.yaml --ignore-not-found=true
    kubectl delete -f envoy-extension-policy.yaml --ignore-not-found=true
    kubectl delete -f envoy-gateway.yaml --ignore-not-found=true
    kubectl delete -f kyverno-verify-signed-images.yaml --ignore-not-found=true
    kubectl delete -f kafka-single-node.yaml --ignore-not-found=true
    kubectl delete -f prometheus-config.yaml --ignore-not-found=true
    kubectl delete -f prometheus.yaml --ignore-not-found=true
    kubectl delete -f grafana.yaml --ignore-not-found=true

    echo "All resources deleted!"
fi

echo ""
read -p "Delete Argo CD namespace 'argocd'? (y/N): " delete_argocd

if [[ $delete_argocd == [yY] || $delete_argocd == [yY][eE][sS] ]]; then
    echo "Deleting Argo CD namespace..."
    kubectl delete namespace argocd --ignore-not-found=true
fi

echo ""
read -p "Uninstall Kyverno controller and namespace '${KYVERNO_NAMESPACE}'? (y/N): " delete_kyverno

if [[ $delete_kyverno == [yY] || $delete_kyverno == [yY][eE][sS] ]]; then
    echo "Uninstalling Kyverno..."
    kubectl delete -f "$KYVERNO_INSTALL_URL" --ignore-not-found=true || true
    kubectl delete namespace "$KYVERNO_NAMESPACE" --ignore-not-found=true || true
fi

echo ""
read -p "Delete Kind cluster 'sporterz'? (y/N): " delete_cluster

if [[ $delete_cluster == [yY] || $delete_cluster == [yY][eE][sS] ]]; then
    echo "Deleting Kind cluster..."
    kind delete cluster --name sporterz
    echo "Kind cluster deleted!"
fi
