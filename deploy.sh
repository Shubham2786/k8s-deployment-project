#!/usr/bin/env bash
# deploy.sh — One-command deployment for Kubernetes Microservices
# Usage: chmod +x deploy.sh && ./deploy.sh

set -euo pipefail

step() { echo -e "\n\033[36m[$1] $2\033[0m"; }
ok()   { echo -e "\033[32m$1\033[0m"; }
warn() { echo -e "\033[33m$1\033[0m"; }

# ── 1. Check prerequisites ──────────────────────────────────────────
step "1/8" "Checking prerequisites..."
missing=()
command -v docker   &>/dev/null || missing+=(docker)
command -v minikube &>/dev/null || missing+=(minikube)
command -v kubectl  &>/dev/null || missing+=(kubectl)
command -v helm     &>/dev/null || missing+=(helm)

if [ ${#missing[@]} -gt 0 ]; then
    echo "Missing: ${missing[*]}. Install them first." >&2
    exit 1
fi
ok "All prerequisites found."

# ── 2. Start Minikube ───────────────────────────────────────────────
step "2/8" "Starting Minikube..."
if minikube status --format '{{.Host}}' 2>/dev/null | grep -q Running; then
    warn "Minikube already running."
else
    minikube start --cpus=2 --memory=4096
fi

# ── 3. Enable Ingress addon ─────────────────────────────────────────
step "3/8" "Enabling Ingress addon..."
minikube addons enable ingress

# ── 4. Build Docker images ──────────────────────────────────────────
step "4/8" "Building Docker images..."
docker build -t demo-backend:1.0  ./backend
docker build -t demo-frontend:1.0 ./frontend

# ── 5. Load images into Minikube ─────────────────────────────────────
step "5/8" "Loading images into Minikube..."
minikube image load demo-backend:1.0
minikube image load demo-frontend:1.0

# ── 6. Deploy with Helm ─────────────────────────────────────────────
step "6/8" "Deploying with Helm..."
if helm list --short 2>/dev/null | grep -q microservices; then
    warn "Release 'microservices' exists — upgrading..."
    helm upgrade microservices ./helm/microservices-app
else
    helm install microservices ./helm/microservices-app
fi

# ── 7. Wait for pods to be ready ─────────────────────────────────────
step "7/8" "Waiting for pods to be ready..."
kubectl rollout status deployment/backend  --timeout=120s
kubectl rollout status deployment/frontend --timeout=120s

# ── 8. Show status & access info ─────────────────────────────────────
step "8/8" "Deployment complete!"

echo -e "\n\033[35m--- Resources ---\033[0m"
kubectl get deployments
echo ""
kubectl get pods
echo ""
kubectl get services
echo ""
kubectl get ingress

MINIKUBE_IP=$(minikube ip)
echo -e "\n\033[35m--- Access ---\033[0m"
echo "Minikube IP:  $MINIKUBE_IP"
echo "Frontend:     http://$MINIKUBE_IP/"
echo "Backend API:  http://$MINIKUBE_IP/api/hello"
echo ""
warn "If Ingress is not reachable, run: minikube tunnel"
warn "Then access at http://127.0.0.1/"
