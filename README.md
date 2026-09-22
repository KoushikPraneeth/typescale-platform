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

The scheduled `Propose TypeScale image update` workflow discovers the newest successful
`typescale-app` main-branch build, resolves its registry digest, validates the rendered
release, and opens a pull request. It never changes the cluster directly and never
auto-merges the proposal.

The original hand-applied `typescale` namespace was deleted before the GitOps bootstrap.
This explicit ownership transfer prevents two controllers or two LoadBalancer Services
from managing competing copies of the same workload.

## Propose an image update

The workflow runs every six hours and can also be started manually:

```bash
gh workflow run propose-image-update.yaml \
  --repo KoushikPraneeth/typescale-platform
```

If the latest successful application image is already approved, the run exits without
creating a branch. Otherwise it creates or refreshes one stable reviewable pull request
containing only the immutable tag and digest update. A newer proposal supersedes the old
one instead of leaving rollback-prone stale image PRs open. The proposal job performs the
same strict Helm and kubeconform validation itself because GitHub suppresses new workflow
events created with the repository `GITHUB_TOKEN`.

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
