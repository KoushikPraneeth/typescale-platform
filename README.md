# TypeScale Platform

GitOps and infrastructure configuration for [TypeScale](https://github.com/KoushikPraneeth/typescale-app).

## Environment boundaries

- **OrbStack Kubernetes** is the primary runtime for TypeScale, Argo CD, monitoring, and autoscaling.
- **Azure and Floci are intentionally out of scope for this milestone.** No cloud deployment is created or required.

## Repository layout

```text
argocd/
  bootstrap.yaml          # one-time app-of-apps bootstrap
  applications/           # continuously reconciled Argo CD Applications
  install/values.yaml     # lightweight local Argo CD configuration
charts/typescale/         # deployable TypeScale Helm chart
monitoring/               # pinned Prometheus, Grafana, and KEDA values
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

CI also renders the pinned Prometheus `29.31.1`, Grafana `13.2.5`, and KEDA `2.20.2`
charts. Prometheus scrapes only annotated TypeScale application pods in
`typescale-gitops`; Alertmanager, kube-state-metrics, node-exporter, Pushgateway,
and persistent storage are disabled for the 8 GB local environment.

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

Before the first Grafana reconciliation, create its admin Secret locally without placing
the generated password in Git. In Fish:

```fish
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
set -l grafana_password (openssl rand -hex 24)
kubectl create secret generic grafana-admin \
  --namespace monitoring \
  --from-literal=admin-user=admin \
  --from-literal="admin-password=$grafana_password"
set -e grafana_password
```

The dashboard is available anonymously as read-only over a local port-forward. Prometheus
and Grafana remain private `ClusterIP` Services:

```bash
kubectl port-forward service/prometheus-server -n monitoring 9090:80
kubectl port-forward service/grafana -n monitoring 3000:80
```

Grafana provisions the Prometheus datasource and the **TypeScale Overview** dashboard from
Git. KEDA watches only `typescale-gitops`. The approved TypeScale values enable a
Prometheus-backed `ScaledObject` with a two-replica minimum and five-replica maximum.
Argo CD ignores `/spec/replicas` and respects that ignore during sync so KEDA/HPA owns
replica changes without hiding drift in any other Deployment field.

Inspect reconciliation without exposing Argo CD publicly:

```bash
kubectl get applications -n argocd
kubectl get pods -n argocd
kubectl get pods -n monitoring
kubectl get pods -n keda
kubectl get pods -n typescale-gitops
kubectl port-forward service/argocd-server -n argocd 8080:80
```

Argo CD is intentionally a private `ClusterIP`. Dex, notifications, and the ApplicationSet controller are disabled to stay within an 8 GB local-machine budget.

## Verified local demonstration

The complete OrbStack path was exercised after platform PR #5 merged:

- Prometheus discovered exactly two healthy `typescale-pods` targets and the idle aggregate was `0`.
- Grafana reported a healthy database and loaded the Git-provisioned Prometheus datasource and `typescale-overview` dashboard.
- KEDA reported `Ready=True`, `Fallback=False`, and created an HPA with a 2–5 replica range.
- The synthetic loader opened and held 40 WebSockets with `40` successful clients and `0` failures.
- Prometheus returned an aggregate active-connection value of `40`.
- KEDA scaled the TypeScale Deployment from two to five ready replicas.
- After the clients closed, the metric returned to zero and the configured stabilization reduced replicas gradually back to two.
- Every Argo CD Application finished `Synced` and `Healthy`, and the public readiness endpoint remained healthy.

This proves the local monitoring and demand-scaling path. It does not imply production
durability: Prometheus and Redis are ephemeral, and existing WebSockets disconnect if the
pod holding them is terminated.
