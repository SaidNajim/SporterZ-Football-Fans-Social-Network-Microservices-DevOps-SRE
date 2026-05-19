#!/bin/bash

echo "=========================================="
echo "SporterZ Cluster Status"
echo "=========================================="

if ! kubectl config current-context | grep -q "kind-sporterz"; then
    echo "Warning: Current context is not kind-sporterz"
    echo "Current context: $(kubectl config current-context 2>/dev/null || echo 'none')"
    echo ""
fi

echo ""
echo "Context: $(kubectl config current-context)"
echo ""
echo "Pods:"
kubectl get pods

echo ""
echo "Services:"
kubectl get svc

echo ""
echo "Gateway + WAF:"
kubectl get gateway sporterz-gateway 2>/dev/null || echo "   sporterz-gateway not found"
kubectl get httproute api-gateway-route 2>/dev/null || echo "   api-gateway-route not found"
kubectl get envoyextensionpolicy coraza-waf-poc 2>/dev/null || echo "   coraza-waf-poc not found"
kubectl get backendtrafficpolicy rate-limit-policy 2>/dev/null || echo "   rate-limit-policy not found"
kubectl get pods -n redis-system 2>/dev/null || echo "   redis-system not found"
kubectl get svc -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=sporterz-gateway -o wide 2>/dev/null || echo "   envoy data-plane service not found"

echo ""
echo "Kyverno:"
kubectl get clusterpolicy verify-signed-sporterz-images 2>/dev/null || echo "   verify-signed-sporterz-images policy not found"
if kubectl get namespace kyverno >/dev/null 2>&1; then
    kubectl get pods -n kyverno
else
    echo "   kyverno namespace not found"
fi

echo ""
echo "Argo CD:"
if kubectl get namespace argocd >/dev/null 2>&1; then
    kubectl get pods -n argocd
    kubectl get applicationsets.argoproj.io -n argocd 2>/dev/null || echo "   no ApplicationSets found"
    kubectl get applications.argoproj.io -n argocd 2>/dev/null || echo "   no Applications found"
    echo ""
    echo "ArgoCD Image Updater:"
    kubectl get deploy/argocd-image-updater -n argocd 2>/dev/null || echo "   argocd-image-updater not found"
else
    echo "   argocd namespace not found"
fi

echo ""
echo "Persistent Volumes:"
kubectl get pvc 2>/dev/null || echo "   No PVCs found"

echo ""
echo "Recent Events (last 10):"
kubectl get events --sort-by='.lastTimestamp' | tail -10
