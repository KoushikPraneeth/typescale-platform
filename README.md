# TypeScale Platform

GitOps and infrastructure configuration for [TypeScale](https://github.com/KoushikPraneeth/typescale-app).

## Environment boundaries

- **OrbStack Kubernetes** is the primary runtime for TypeScale, Argo CD, monitoring, and autoscaling.
- **Floci AZ** will be a separate Azure API/Terraform compatibility test environment. It is not the application runtime and is not equivalent to Azure.
- **Real Azure** remains a future validation target; no paid Azure subscription is required for this local platform.

## Repository layout

```text
argocd/
  bootstrap.yaml          # one-time app-of-apps bootstrap
  applications/           # continuously reconciled Argo CD Applications
  install/values.yaml     # lightweight local Argo CD configuration
charts/typescale/         # deployable TypeScale Helm chart
```

## Delivery ownership

1. `typescale-app` tests, builds, and scans the application.
2. A successful `main` run publishes an immutable GHCR image tagged with the full commit SHA.
3. This repository records the approved image tag and digest in `charts/typescale/values-gitops.yaml`.
4. Argo CD reconciles that approved configuration into `typescale-gitops`.

GitHub Actions does **not** deploy the application. Argo CD is the only deployment reconciler.

## Validate locally

```bash
helm lint --strict charts/typescale -f charts/typescale/values-gitops.yaml
helm template typescale charts/typescale \
  --namespace typescale-gitops \
  -f charts/typescale/values-gitops.yaml
```

## Install lightweight Argo CD

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update argo
helm upgrade --install argocd argo/argo-cd \
  --version 10.9.2 \
  --namespace argocd \
  --create-namespace \
  -f argocd/install/values.yaml \
  --wait \
  --timeout 5m \
  --rollback-on-failure

kubectl apply -f argocd/bootstrap.yaml
```

Inspect reconciliation without exposing Argo CD publicly:

```bash
kubectl get applications -n argocd
kubectl get pods -n argocd
kubectl get pods -n typescale-gitops
kubectl port-forward service/argocd-server -n argocd 8080:80
```

Argo CD is intentionally a private `ClusterIP`. Dex, notifications, and the ApplicationSet controller are disabled to stay within an 8 GB local-machine budget.
