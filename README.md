# Kubernetes Microservices Deployment & CI/CD

## Overview

A microservices application deployed on **Kubernetes (Minikube)** demonstrating containerization, service discovery, horizontal scaling, health probes, resource management, rolling updates, Helm-based deployments, and Nginx Ingress routing.

The project consists of two services:
- **Frontend** — Static HTML/CSS/JS served by Nginx
- **Backend** — Python Flask API returning JSON responses

---

## Quick Start

One command to deploy everything:

```powershell
# Windows PowerShell
.\deploy.ps1
```

```bash
# Linux / macOS
chmod +x deploy.sh && ./deploy.sh
```

This will: start Minikube → enable Ingress → build Docker images → load them → deploy with Helm → wait for readiness → print access URLs.

---

## Architecture

```
┌────────────────────────────────────────────────────────┐
│                        Minikube                        │
│                                                        │
│  ┌───────────────────────────────────────────────────┐ │
│  │              Nginx Ingress Controller             │ │
│  └──────────┬────────────────────────┬───────────────┘ │
│             │                        │                 │
│         /   │                   /api │                 │
│             ▼                        ▼                 │
│  ┌──────────────────┐    ┌──────────────────────┐      │
│  │ frontend-service │    │  backend-service     │      │
│  │   (ClusterIP)    │    │   (ClusterIP)        │      │
│  └────────┬─────────┘    └────────┬─────────────┘      │
│           │                       │                    │
│     ┌─────┴─────┐          ┌─────┴─────┐               │
│     ▼           ▼          ▼           ▼               │
│  ┌──────┐  ┌──────┐   ┌──────┐   ┌──────┐              │
│  │ Pod  │  │ Pod  │   │ Pod  │   │ Pod  │              │
│  │nginx │  │nginx │   │flask │   │flask │              │
│  └──────┘  └──────┘   └──────┘   └──────┘              │
│                                                        │
└────────────────────────────────────────────────────────┘
```

**Request flow:**
1. Browser sends request to Minikube IP
2. Nginx Ingress Controller receives the request
3. Path-based routing directs `/` to frontend, `/api` to backend
4. The Kubernetes Service load-balances across available Pods

---

## Technologies Used

| Technology | Purpose |
|------------|---------|
| Docker | Containerize frontend and backend services |
| Kubernetes | Orchestrate and manage containerized workloads |
| Minikube | Local single-node Kubernetes cluster |
| Helm | Package and deploy Kubernetes resources using reusable charts |
| Nginx | Serve frontend static files |
| Nginx Ingress | Path-based traffic routing into the cluster |
| Flask | Lightweight Python backend API |
| GitHub Actions | CI pipeline to build Docker images |

---

## Repository Structure

```
├── frontend/
│   ├── index.html          # Frontend page with "Call Backend" button
│   ├── nginx.conf          # Nginx configuration for serving static files
│   └── Dockerfile          # Nginx-based container image
│
├── backend/
│   ├── app.py              # Flask API with /api/hello and /health
│   ├── requirements.txt    # Python dependencies (flask only)
│   └── Dockerfile          # Python-based container image
│
├── k8s/
│   ├── frontend-deployment.yaml
│   ├── frontend-service.yaml
│   ├── backend-deployment.yaml
│   ├── backend-service.yaml
│   └── ingress.yaml
│
├── helm/
│   └── microservices-app/
│       ├── Chart.yaml       # Chart metadata
│       ├── values.yaml      # Configurable deployment values
│       └── templates/       # Templated Kubernetes manifests
│           ├── frontend-deployment.yaml
│           ├── frontend-service.yaml
│           ├── backend-deployment.yaml
│           ├── backend-service.yaml
│           └── ingress.yaml
│
├── .github/
│   └── workflows/
│       └── ci.yaml          # GitHub Actions CI pipeline
│
├── .gitignore
├── deploy.ps1              # One-command deploy (Windows PowerShell)
├── deploy.sh               # One-command deploy (Linux/macOS)
└── README.md
```

---

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed
- [Minikube](https://minikube.sigs.k8s.io/docs/start/) installed
- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed
- [Helm](https://helm.sh/docs/intro/install/) installed

Verify installations:

```bash
docker --version
minikube version
kubectl version --client
helm version
```

---

## Docker Setup

### Build Images

```bash
docker build -t demo-backend:1.0 ./backend
docker build -t demo-frontend:1.0 ./frontend
```

### Test Locally (optional)

```bash
# Run backend
docker run -d -p 5000:5000 demo-backend:1.0
curl http://localhost:5000/api/hello
curl http://localhost:5000/health

# Run frontend
docker run -d -p 8080:80 demo-frontend:1.0
# Open http://localhost:8080 in browser
```

---

## Minikube Setup

### Start Minikube

```bash
minikube start
```

### Enable Ingress addon

```bash
minikube addons enable ingress
```

### Load Docker images into Minikube

Minikube runs its own Docker daemon. Images built on your host machine are not automatically available inside Minikube. You need to load them.

**Option A — Load images directly (recommended for Windows):**

```bash
minikube image load demo-backend:1.0
minikube image load demo-frontend:1.0
```

**Option B — Build inside Minikube's Docker daemon:**

```bash
# On Linux/macOS:
eval $(minikube docker-env)

# On Windows PowerShell:
& minikube -p minikube docker-env --shell powershell | Invoke-Expression

# Then build images (they'll be built inside Minikube):
docker build -t demo-backend:1.0 ./backend
docker build -t demo-frontend:1.0 ./frontend
```

### Verify images are available

```bash
minikube image list | grep demo
```

---

## Kubernetes Deployment

### Option 1: Deploy with raw manifests

```bash
kubectl apply -f k8s/
```

### Option 2: Deploy with Helm

```bash
helm install microservices ./helm/microservices-app
```

> Use one method or the other, not both simultaneously.

### Verify deployment

```bash
kubectl get deployments
kubectl get pods
kubectl get services
kubectl get ingress
```

Expected output:
```
NAME       READY   UP-TO-DATE   AVAILABLE
backend    2/2     2            2
frontend   2/2     2            2
```

### Access the application

```bash
# Get Minikube IP
minikube ip
```

Open `http://<minikube-ip>` in your browser.

**On Windows**, if the Ingress is not directly accessible, use:

```bash
minikube tunnel
```

Then access the application at `http://127.0.0.1`.

---

## Service Discovery

Kubernetes provides DNS-based service discovery. Every Service gets a DNS entry in the format:

```
<service-name>.<namespace>.svc.cluster.local
```

In this project, the backend is accessible within the cluster as:

```
backend-service.default.svc.cluster.local:5000
```

Or simply:

```
backend-service:5000
```

### How it works

```
Frontend Pod (browser request to /api/hello)
    │
    ▼
Nginx Ingress Controller (routes /api → backend-service)
    │
    ▼
backend-service (ClusterIP Service)
    │
    ▼ (Kubernetes distributes to one of the backend Pods)
    │
Backend Pod (returns JSON response with pod hostname)
```

The frontend calls `/api/hello` using a **relative URL**. The Ingress Controller intercepts the request and routes it to `backend-service`, which resolves via Kubernetes DNS. The Service then load-balances across all backend Pods.

### Verify service discovery

```bash
# Exec into a pod and test DNS resolution
kubectl exec -it <any-pod-name> -- nslookup backend-service
```

Click the "Call Backend API" button multiple times — the `pod` field in the response will show different hostnames, proving traffic is distributed across pods.

---

## Horizontal Scaling

The backend Deployment starts with `replicas: 2`. You can manually scale up or down.

### Scale to 3 replicas

```bash
kubectl scale deployment backend --replicas=3
```

### Verify

```bash
kubectl get pods -l app=backend
```

Expected output:
```
NAME                       READY   STATUS    RESTARTS
backend-5d4f8c7b9-abc12   1/1     Running   0
backend-5d4f8c7b9-def34   1/1     Running   0
backend-5d4f8c7b9-ghi56   1/1     Running   0
```

### Scale back down

```bash
kubectl scale deployment backend --replicas=2
```

The Kubernetes Service automatically distributes traffic across however many replicas are running. No configuration change is needed on the Service side.

---

## Health Probes

Both deployments configure **readiness** and **liveness** probes.

### Backend probes

| Probe | Endpoint | Initial Delay | Period | Failure Threshold |
|-------|----------|---------------|--------|-------------------|
| Readiness | `GET /health` on port 5000 | 5s | 5s | 3 |
| Liveness | `GET /health` on port 5000 | 10s | 10s | 3 |

### Frontend probes

| Probe | Endpoint | Initial Delay | Period | Failure Threshold |
|-------|----------|---------------|--------|-------------------|
| Readiness | `GET /` on port 80 | 5s | 5s | 3 |
| Liveness | `GET /` on port 80 | 10s | 10s | 3 |

### Readiness vs Liveness

| | Readiness Probe | Liveness Probe |
|--|----------------|----------------|
| **Purpose** | Is the Pod ready to receive traffic? | Is the container still alive? |
| **On failure** | Pod is removed from Service endpoints (no traffic sent to it) | Container is restarted |
| **Use case** | App is starting up or temporarily unavailable | App is stuck or deadlocked |

### Verify probes

```bash
kubectl describe pod <pod-name>
```

Look for the `Conditions` section:
```
Conditions:
  Ready:   True
```

And the `Events` section for probe activity.

---

## Resource Limits

Both deployments define CPU and memory **requests** and **limits**.

### Backend resources

```yaml
resources:
  requests:
    cpu: 100m      # 0.1 CPU cores guaranteed
    memory: 128Mi  # 128 MB guaranteed
  limits:
    cpu: 500m      # 0.5 CPU cores maximum
    memory: 256Mi  # 256 MB maximum
```

### Frontend resources

```yaml
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 128Mi
```

### Requests vs Limits

| | Requests | Limits |
|--|----------|--------|
| **Purpose** | Minimum resources guaranteed to the container | Maximum resources the container can use |
| **Scheduling** | Kubernetes uses requests to decide which node to place the Pod on | Not used for scheduling |
| **Enforcement** | Resources are reserved but the container can use more (up to limits) | CPU is throttled; memory exceeding limits causes OOMKill |

### What happens when limits are exceeded

- **CPU limit exceeded** → The container is **throttled** (slowed down), not killed
- **Memory limit exceeded** → The container is **OOMKilled** (terminated) and restarted by Kubernetes

### Verify

```bash
kubectl describe pod <pod-name>
```

Look for the `Limits` and `Requests` fields under `Containers`.

---

## Rolling Updates

Both Deployments use `RollingUpdate` strategy:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1        # Create at most 1 extra Pod during update
    maxUnavailable: 0  # Always keep all desired Pods running
```

### Demonstrate a rolling update

**Step 1:** Verify current deployment:

```bash
kubectl rollout status deployment/backend
```

**Step 2:** Modify the backend response. Edit `backend/app.py` and change the message:

```python
"message": "Hello from Kubernetes backend v2"
```

**Step 3:** Build version 2:

```bash
docker build -t demo-backend:2.0 ./backend
minikube image load demo-backend:2.0
```

**Step 4:** Update the deployment:

```bash
kubectl set image deployment/backend backend=demo-backend:2.0
```

**Step 5:** Watch the rollout:

```bash
kubectl rollout status deployment/backend
```

Output:
```
Waiting for deployment "backend" rollout to finish: 1 out of 2 new replicas have been updated...
deployment "backend" successfully rolled out
```

### View rollout history

```bash
kubectl rollout history deployment/backend
```

### Rollback to previous version

```bash
kubectl rollout undo deployment/backend
```

### How rolling updates work

1. Kubernetes creates a **new ReplicaSet** with the updated image
2. New Pods are created in the new ReplicaSet (up to `maxSurge`)
3. Once new Pods pass readiness probes, old Pods are terminated
4. This continues until all Pods run the new version
5. The old ReplicaSet is kept (with 0 replicas) for rollback

```
Before:   [Pod v1] [Pod v1]
During:   [Pod v1] [Pod v1] [Pod v2]  ← new Pod created (maxSurge: 1)
During:   [Pod v1] [Pod v2]           ← old Pod removed after new is ready
After:    [Pod v2] [Pod v2]           ← rollout complete
```

---

## Pod Failure & Recovery

Kubernetes automatically replaces failed Pods to maintain the desired replica count.

### Demonstrate pod recovery

**Step 1:** List pods:

```bash
kubectl get pods -l app=backend
```

**Step 2:** Delete a pod:

```bash
kubectl delete pod <pod-name>
```

**Step 3:** Immediately check pods:

```bash
kubectl get pods -l app=backend
```

You will see a new Pod being created to replace the deleted one.

### Why this works

```
Deployment (desired replicas: 2)
    │
    ▼
ReplicaSet (ensures 2 pods are always running)
    │
    ├── Pod 1 (running)
    └── Pod 2 (deleted → ReplicaSet creates Pod 3)
```

The **Deployment** defines the desired state (e.g., 2 replicas). The **ReplicaSet** continuously monitors and ensures the actual number of Pods matches the desired count. When a Pod is deleted, the ReplicaSet detects the discrepancy and creates a replacement.

---

## Nginx Ingress

The Nginx Ingress Controller provides external access to services with path-based routing.

### Enable Ingress on Minikube

```bash
minikube addons enable ingress
```

### Path-based routing

```
Browser Request
    │
    ▼
Nginx Ingress Controller
    │
    ├── /           → frontend-service:80  → Frontend Pods (Nginx)
    │
    └── /api/hello  → backend-service:5000 → Backend Pods (Flask)
```

### Key concepts

| Concept | Explanation |
|---------|-------------|
| **Ingress** | A Kubernetes resource that defines routing rules (which paths go to which Services) |
| **Ingress Controller** | The actual software (Nginx) that reads Ingress rules and routes traffic accordingly |
| **Why Services are still needed** | Ingress routes to Services, not directly to Pods. Services provide stable endpoints and load balancing across Pod replicas |
| **Path-based routing** | Different URL paths are directed to different backend Services |

### Verify Ingress

```bash
kubectl get ingress
kubectl describe ingress microservices-ingress
```

### Access the application

```bash
# Get the Minikube IP
minikube ip

# Test frontend
curl http://<minikube-ip>/

# Test backend API
curl http://<minikube-ip>/api/hello
```

**Windows users**: If direct access doesn't work, run `minikube tunnel` in a separate terminal, then access via `http://127.0.0.1`.

---

## Helm Deployment

### What is Helm?

Helm is a package manager for Kubernetes. It packages Kubernetes manifests into reusable **charts** with configurable values.

| Concept | Explanation |
|---------|-------------|
| **Chart** | A package of templated Kubernetes manifests |
| **values.yaml** | Default configuration values for the chart |
| **Templates** | Kubernetes YAML files with Go template variables (e.g., `{{ .Values.backend.replicas }}`) |
| **Release** | A deployed instance of a chart |

### Install with Helm

```bash
helm install microservices ./helm/microservices-app
```

### Verify

```bash
helm list
helm status microservices
```

### Upgrade with custom values

Change a value (e.g., scale backend to 3 replicas):

```bash
helm upgrade microservices ./helm/microservices-app --set backend.replicas=3
```

Or edit `values.yaml` and run:

```bash
helm upgrade microservices ./helm/microservices-app
```

### Uninstall

```bash
helm uninstall microservices
```

### How templates work

In `values.yaml`:
```yaml
backend:
  replicas: 2
  image:
    repository: demo-backend
    tag: "1.0"
```

In `templates/backend-deployment.yaml`:
```yaml
replicas: {{ .Values.backend.replicas }}
image: "{{ .Values.backend.image.repository }}:{{ .Values.backend.image.tag }}"
```

Helm renders the templates with the values to produce the final Kubernetes manifests. This makes deployments configurable and reproducible.

---

## Verification

### Check all resources

```bash
kubectl get pods
kubectl get deployments
kubectl get services
kubectl get ingress
```

### Inspect a specific pod

```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Helm verification

```bash
helm list
helm status microservices
```

### Rollout verification

```bash
kubectl rollout status deployment/backend
kubectl rollout history deployment/backend
```

### Scaling verification

```bash
kubectl scale deployment backend --replicas=3
kubectl get pods -l app=backend
```

---

## Troubleshooting

### ImagePullBackOff

**Cause:** Kubernetes cannot pull the Docker image.

```bash
kubectl describe pod <pod-name>
```

**Fix:** Ensure images are loaded into Minikube:
```bash
minikube image load demo-backend:1.0
minikube image load demo-frontend:1.0
```

Also verify `imagePullPolicy: Never` is set in the Deployment.

---

### CrashLoopBackOff

**Cause:** The container starts but crashes immediately.

```bash
kubectl logs <pod-name>
kubectl logs <pod-name> --previous
```

**Fix:** Check the application code for errors. Common causes:
- Missing dependencies
- Port conflicts
- Syntax errors

---

### Readiness Probe Failure

**Symptom:** Pod shows `Running` but `0/1 READY`.

```bash
kubectl describe pod <pod-name>
```

Look for: `Readiness probe failed: ...`

**Fix:** Ensure the health endpoint is running and returns HTTP 200.

---

### Backend Service Unreachable

```bash
kubectl get endpoints backend-service
```

If endpoints list is empty, the Service selector doesn't match any Pods.

```bash
kubectl get pods --show-labels
kubectl describe service backend-service
```

**Fix:** Ensure the `selector` in the Service matches the `labels` on the Pods.

---

### Ingress Not Working

```bash
kubectl get ingress
kubectl describe ingress microservices-ingress
kubectl get pods -n ingress-nginx
```

**Fix:**
1. Ensure the Ingress addon is enabled: `minikube addons enable ingress`
2. Wait for the Ingress controller pod to be running
3. On Windows, run `minikube tunnel`

---

### Pods Not Starting

```bash
kubectl get events --sort-by=.metadata.creationTimestamp
kubectl describe pod <pod-name>
```

Common causes:
- Insufficient resources (increase Minikube resources: `minikube start --cpus=4 --memory=4096`)
- Image not found (load into Minikube)
- Invalid YAML (check syntax)

---

## Kubernetes Concepts Demonstrated

| Concept | Where Demonstrated |
|---------|-------------------|
| **Pods** | Smallest deployable unit — each container runs in a Pod |
| **Deployments** | Manages ReplicaSets and rolling updates for frontend and backend |
| **ReplicaSets** | Ensures the desired number of Pod replicas are running |
| **Services (ClusterIP)** | Provides stable internal DNS and load balancing |
| **Ingress** | External access with path-based routing |
| **Health Probes** | Readiness and liveness probes on both services |
| **Resource Management** | CPU/memory requests and limits |
| **Rolling Updates** | Zero-impact deployment of new versions |
| **Self-healing** | Automatic Pod replacement on failure |
| **Horizontal Scaling** | Manual replica scaling via `kubectl scale` |
| **Helm Charts** | Templated, reusable Kubernetes deployments |
| **Service Discovery** | DNS-based communication between services |

---

## Cleanup

### Remove Kubernetes resources

```bash
# If deployed with raw manifests:
kubectl delete -f k8s/

# If deployed with Helm:
helm uninstall microservices
```

### Stop Minikube

```bash
minikube stop
```

### Delete Minikube cluster

```bash
minikube delete
```
