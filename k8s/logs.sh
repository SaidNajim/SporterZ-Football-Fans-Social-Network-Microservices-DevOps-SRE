#!/bin/bash

SERVICE=$1

if ! kubectl config current-context | grep -q "kind-sporterz"; then
    echo "Warning: Current context is not kind-sporterz"
    echo "Current context: $(kubectl config current-context 2>/dev/null || echo 'none')"
    echo ""
fi

if [ -z "$SERVICE" ]; then
    echo "Usage: ./logs.sh <service-name>"
    echo ""
    echo "Available services:"
    echo "  auth-service"
    echo "  posts-service"
    echo "  match-service"
    echo "  messaging-service"
    echo "  api-gateway"
    echo "  frontend"
    echo "  kafka"
    echo "  kyverno"
    echo "  argocd"
    echo "  argocd-image-updater"
    exit 1
fi

case $SERVICE in
    auth-service)
        LABEL="app=auth-service"
        ;;
    posts-service)
        LABEL="app=posts-service"
        ;;
    match-service)
        LABEL="app=match-service"
        ;;
    messaging-service)
        LABEL="app=messaging-service"
        ;;
    api-gateway)
        LABEL="app=api-gateway"
        ;;
    frontend)
        LABEL="app=frontend"
        ;;
    kafka)
        LABEL="app=kafka"
        ;;
    kyverno)
        echo "Showing logs for kyverno-admission-controller (follow mode, Ctrl+C to exit)..."
        kubectl logs -f -n kyverno deploy/kyverno-admission-controller --tail=100
        exit 0
        ;;
    argocd)
        echo "Showing logs for ArgoCD server (follow mode, Ctrl+C to exit)..."
        kubectl logs -f -n argocd deploy/argocd-server --tail=100
        exit 0
        ;;
    argocd-image-updater)
        echo "Showing logs for ArgoCD Image Updater (follow mode, Ctrl+C to exit)..."
        kubectl logs -f -n argocd deploy/argocd-image-updater --tail=100
        exit 0
        ;;
    *)
        echo "Unknown service: $SERVICE"
        exit 1
        ;;
esac

echo "Showing logs for $SERVICE (follow mode, Ctrl+C to exit)..."
kubectl logs -f -l $LABEL --tail=100
