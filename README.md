# Deploy an app to Kubernetes (AkOps Labs build project)

Run a web app on Kubernetes the way production teams do: **2 replicas** with health probes and resource limits,
a **Service** in front of them, an **Ingress** for outside traffic and an **autoscaler (HPA)** for busy days.

**Level:** Intermediate · **Time:** about 60 minutes · **Tools:** Kubernetes, kubectl, YAML

## What to build (in `k8s/`)

| File | What it needs |
|---|---|
| `deployment.yaml` | `web`, **2 replicas**, a pinned image (`nginx:1.27-alpine`, not `latest`), `resources` requests + limits, `readinessProbe` and `livenessProbe` (httpGet `/` on port 80) |
| `service.yaml` | `web`, type `ClusterIP`, selects `app: web`, port 80 → 80 |
| `ingress.yaml` | `networking.k8s.io/v1`, class `nginx`, path `/` (Prefix) → service `web` port 80 |
| `hpa.yaml` | `autoscaling/v2`, scales Deployment `web` between 2 and 5 replicas at 70% CPU |

## Run it

```bash
kind create cluster            # or minikube start
kubectl apply -f k8s/
kubectl rollout status deployment/web
kubectl get pods,svc,ingress,hpa
kubectl port-forward svc/web 8080:80   # then: curl localhost:8080
```

Push to `main`. The **AkOps check** workflow creates a real Kubernetes cluster on GitHub, applies your files and tests the app.
