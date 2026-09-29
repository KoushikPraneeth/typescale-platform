# Temporary AKS TypeScale lab

This stack is a disposable AKS/ACR environment for the v1.1 Kubernetes-specific proof described in the project plan. It is not a production cluster and must not be left running.

## Architecture and guardrails

- One dedicated resource group, one AKS cluster, one small Basic ACR, and no Azure Managed Redis. TypeScale's Redis remains an in-cluster `ClusterIP`, with the chart NetworkPolicy allowing Redis ingress only from the app pods.
- AKS starts with one `Standard_D2s_v5` node and a cluster autoscaler range of one to two nodes. The AKS **Free control-plane tier does not make worker VMs or networking free**.
- Public AKS API is restricted to one required operator IPv4 `/32`; local Kubernetes accounts are disabled and Azure RBAC is used. The app is the only public service. Prometheus, Grafana, Argo CD, KEDA, and Redis stay `ClusterIP`/cluster-internal.
- ACR admin credentials are disabled. AKS kubelet managed identity receives only registry-scoped `AcrPull`; no registry password is stored in a Kubernetes Secret.
- Terraform tags every resource for TypeScale/demo cleanup. Terraform state and plan files can contain credential/configuration material and must remain local, ignored, and outside GitHub.
- **Do not apply until Azure for Students' current credit/usage has been checked and the user-approved spend cap is known.** A temporary AKS cluster still incurs node VM, OS disk, load balancer/public IP, ACR storage, and possible egress charges. This repository makes no cost or zero-cost guarantee. Do not create a budget, upgrade the subscription, or add payment details.

## Preflight (required before apply)

1. Confirm the active subscription is `Azure for Students` and `Enabled`; never switch to another subscription to bypass a quota or policy denial.
2. Check Cost Management and Student-credit balance in the Azure Portal. The `az consumption balance` command is not supported in all CLI versions. Stop if current credit or the expected lab charge cannot be established. Obtain an explicit maximum spend for the lab before provisioning.
3. Check the selected region, current AKS versions, VM SKU quota/capacity, ACR name availability, and current egress IP. Use an operator IP `/32` for the API allowlist. Do not weaken API access to `0.0.0.0/0` to work around network access.
4. Verify `ssh_public_key_path` resolves to a public `.pub` key. Never pass a private key.
5. Review the exact Terraform plan. It must contain one RG, one Basic ACR, one AKS cluster, and the expected scoped role assignments; no managed Redis, Log Analytics workspace, or unrelated resources.

For rough planning only, the Azure Retail Prices API returned Canada Central list rates of USD 0.107/node-hour for Linux `Standard_D2s_v5`, USD 0.1666/day for Basic ACR, USD 0.025/hour for the Standard Load Balancer, and USD 10.208/month for a P6 64-GiB Premium SSD. At one node, those components subtotal about USD 0.75 for four hours or USD 1.04 for six hours, before public IP, bandwidth/egress, taxes, possible SKU differences, or any second node. This is **not** the account's actual charge or credit balance and is not an enforceable cap; verify the current Student credit and Cost Management data in the Portal before apply. The second node adds at least another VM-hour and disk usage while running.

## Provision and authenticate

Run from this directory with Terraform `1.16.3` and AzureRM provider `4.x`. Keep local state and saved plans in a temporary scratch directory (not the repository):

```sh
export STATE_DIR="$HOME/.hermes/cache/scratch/typescale-aks-state"
mkdir -p "$STATE_DIR"
terraform init -backend-config="path=$STATE_DIR/terraform.tfstate"
terraform fmt -check -recursive
terraform validate
terraform plan -out="$STATE_DIR/aks.tfplan" \
  -var='acr_name=<globally-unique-lowercase-name>' \
  -var='kubernetes_version=<supported-version>' \
  -var='admin_source_cidr=<current-public-ip>/32'
```

Only after the cost gate, authorization, and plan review, apply the saved plan:

```sh
terraform apply "$STATE_DIR/aks.tfplan"
```

The cluster is configured for Microsoft Entra ID + Azure RBAC, with local accounts disabled. The signed-in Terraform principal is granted cluster-user credentials and the AKS RBAC Cluster Admin role at the cluster resource scope. This does not grant extra subscription-level rights. Retrieve user credentials (not `--admin`) and verify the context, node count, and API access:

```sh
az aks get-credentials --resource-group rg-typescale-aks-demo --name typescale-aks-demo
kubectl config current-context
kubectl get nodes -o wide
```

If the machine's egress IP changes, update the `/32` allowlist through Terraform; do not open the API server broadly.

## Publish/pull the tested image

Import the already-tested immutable GHCR image to the temporary ACR (no rebuild, no mutable `latest` tag), record the ACR digest, and verify it matches the source digest:

```sh
az acr import --name "$ACR_NAME" \
  --source ghcr.io/koushikpraneeth/typescale@sha256:7e85ebde40f4797316bb381b52d371c7b800888ccda125b221cb41008e337cd6 \
  --image typescale:056cb02da9a856793f29796526f5916207d59a04
```

The committed AKS values use the tested GHCR digest so the repository remains reproducible after the temporary ACR is destroyed. For the live ACR-backed run, use a disposable Git branch: update `app.image.repository`/`digest` in `values-aks.yaml` to the imported ACR image and update the AKS bootstrap plus its child Applications to track that branch. Push the branch before applying the bootstrap so Argo CD observes the exact branch and digest. Do not merge an ACR-specific image reference into `main`; after AKS is destroyed, delete the temporary branch. This keeps the cluster GitOps-managed without leaving the permanent repo pointed at a registry that no longer exists.

## GitOps bootstrap and verification

1. Install only the Argo CD control plane with the pinned Helm version/values. Keep its Service `ClusterIP`; use a local port-forward for UI/API diagnostics.
2. Create the Grafana admin Secret locally with a randomly generated password, without printing it. The chart expects `admin-user` and `admin-password` keys in Secret `grafana-admin` in namespace `monitoring`; do not commit the Secret.
3. Apply the AKS root Argo CD Application to bootstrap the AKS-specific application set. This is the bootstrap exception; **do not manually `kubectl apply`, `helm install`, or `helm upgrade` TypeScale, Redis, Prometheus, Grafana, or KEDA**. Argo CD must own those workloads and the Git revision containing the AKS values.
4. Keep the app as the only public ingress. Verify the external load-balancer endpoint is HTTP-ready and that `/health/ready` works. Prometheus, Grafana, Argo CD, Redis, and KEDA remain private.
5. Run the 40-client full-race test through the AKS public endpoint (capture the exact image digest, replica count, and JSON/CSV artifacts outside the repository). Required gates: 40/40 connections, 40/40 completed races, zero failures/unexpected disconnects, and documented matchmaking p50/p95/p99. This p95 is matchmaking latency, not race-completion latency.
6. Verify Prometheus target/query, KEDA `ScaledObject`, and actual pod scaling from 2 to 5 while clients are held/active, then back to 2 after the metric reaches zero and cooldown/stabilization completes. A configured range is not proof of autoscaling.
7. Optional node-autoscaler proof is a separate, explicitly cost-approved experiment: create legitimate Pending pods from declared CPU/memory requests, observe node count 1→2 and pods schedule, then observe scale-down. Do not fake load or claim node scaling unless the node count actually changes.
8. Test pod replacement separately and keep any disconnect result explicit. Do not infer zero downtime from successful readiness or HPA scaling.

## Teardown and proof of cleanup

Capture evidence first, then destroy immediately:

```sh
terraform plan -destroy -out="$STATE_DIR/aks-destroy.tfplan"
terraform apply "$STATE_DIR/aks-destroy.tfplan"
az group show --name rg-typescale-aks-demo
az resource list --resource-group rg-typescale-aks-demo -o table
```

The expected postcondition is that the group is not found and no TypeScale resources remain. Remove the local Terraform state, saved plans, provider cache, kubeconfig context, temporary Git branch/image values, generated secrets, and port-forwards only after remote destroy verification. Recheck Cost Management later for delayed charges. Do not claim a zero bill.
