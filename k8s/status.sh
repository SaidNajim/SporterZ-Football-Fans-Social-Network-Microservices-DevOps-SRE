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
kubectl get svc -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=sporterz-gateway -o wide 2>/dev/null || echo "   envoy data-plane service not found"

echo ""
echo "Persistent Volumes:"
kubectl get pvc 2>/dev/null || echo "   No PVCs found"

echo ""
echo "Recent Events (last 10):"
kubectl get events --sort-by='.lastTimestamp' | tail -10
