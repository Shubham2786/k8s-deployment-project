#!/usr/bin/env pwsh
# deploy.ps1 — One-command deployment for Kubernetes Microservices
# Usage: .\deploy.ps1

$ErrorActionPreference = "Stop"

function Write-Step($step, $msg) {
    Write-Host "`n[$step] $msg" -ForegroundColor Cyan
}

function Assert-LastExit($stepName) {
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n[ERROR] '$stepName' failed (exit code $LASTEXITCODE). Aborting deployment." -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

# ── 1. Check prerequisites ──────────────────────────────────────────
Write-Step "1/8" "Checking prerequisites..."
$missing = @()
if (-not (Get-Command docker -ErrorAction SilentlyContinue))   { $missing += "docker" }
if (-not (Get-Command minikube -ErrorAction SilentlyContinue)) { $missing += "minikube" }
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue))  { $missing += "kubectl" }
if (-not (Get-Command helm -ErrorAction SilentlyContinue))     { $missing += "helm" }

if ($missing.Count -gt 0) {
    Write-Host "Missing: $($missing -join ', '). Install them first." -ForegroundColor Red
    exit 1
}

# Check if Docker daemon is running
docker info >$null 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker is installed but the Docker daemon is not running." -ForegroundColor Red
    Write-Host "Please start Docker Desktop and ensure it is fully running before continuing." -ForegroundColor Yellow
    exit 1
}

Write-Host "All prerequisites found and Docker daemon is running." -ForegroundColor Green

# ── 2. Start Minikube ───────────────────────────────────────────────
Write-Step "2/8" "Starting Minikube..."
$status = minikube status --format '{{.Host}}' 2>$null
if ($status -eq "Running") {
    Write-Host "Minikube already running." -ForegroundColor Yellow
} else {
    minikube start --cpus=2 --memory=4096
    Assert-LastExit "minikube start"
}

# ── 3. Enable Ingress addon ─────────────────────────────────────────
Write-Step "3/8" "Enabling Ingress addon..."
minikube addons enable ingress
Assert-LastExit "minikube addons enable ingress"

# ── 4. Build Docker images ──────────────────────────────────────────
Write-Step "4/8" "Building Docker images..."
docker build -t demo-backend:1.0  ./backend
Assert-LastExit "docker build demo-backend:1.0"
docker build -t demo-frontend:1.0 ./frontend
Assert-LastExit "docker build demo-frontend:1.0"

# ── 5. Load images into Minikube ─────────────────────────────────────
Write-Step "5/8" "Loading images into Minikube..."
minikube image load demo-backend:1.0
Assert-LastExit "minikube image load demo-backend:1.0"
minikube image load demo-frontend:1.0
Assert-LastExit "minikube image load demo-frontend:1.0"

# ── 6. Deploy with Helm ─────────────────────────────────────────────
Write-Step "6/8" "Deploying with Helm..."
$release = helm list --short 2>$null | Select-String "microservices"
if ($release) {
    Write-Host "Release 'microservices' exists — upgrading..." -ForegroundColor Yellow
    helm upgrade microservices ./helm/microservices-app
    Assert-LastExit "helm upgrade microservices"
} else {
    helm install microservices ./helm/microservices-app
    Assert-LastExit "helm install microservices"
}

# ── 7. Wait for pods to be ready ─────────────────────────────────────
Write-Step "7/8" "Waiting for pods to be ready..."
kubectl rollout status deployment/backend  --timeout=120s
Assert-LastExit "kubectl rollout status deployment/backend"
kubectl rollout status deployment/frontend --timeout=120s
Assert-LastExit "kubectl rollout status deployment/frontend"

# ── 8. Show status & access info ─────────────────────────────────────
Write-Step "8/8" "Deployment complete!"

Write-Host "`n--- Resources ---" -ForegroundColor Magenta
kubectl get deployments
Write-Host ""
kubectl get pods
Write-Host ""
kubectl get services
Write-Host ""
kubectl get ingress

$minikubeIp = minikube ip
Write-Host "`n--- Access ---" -ForegroundColor Magenta
Write-Host "Minikube IP:  $minikubeIp"
Write-Host "Frontend:     http://$minikubeIp/"
Write-Host "Backend API:  http://$minikubeIp/api/hello"
Write-Host ""
Write-Host "If Ingress is not reachable, run in a separate terminal:" -ForegroundColor Yellow
Write-Host "  minikube tunnel" -ForegroundColor Yellow
Write-Host "Then access at http://127.0.0.1/" -ForegroundColor Yellow
