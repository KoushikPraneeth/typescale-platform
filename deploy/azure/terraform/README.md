# Temporary Azure Container Apps experiment

This Terraform stack creates a dedicated resource group, a Container Apps environment, one fixed-capacity Container App, and Azure Managed Redis. It uses the immutable image digest exercised by the previous Azure run and configures Redis `NoCluster` with TLS and key authentication.

## Scope and safety

- `terraform apply` provisions billable Azure resources; `terraform destroy` removes the whole stack. Do not leave it running after a benchmark.
- Defaults match the two allowed regions used in the earlier run: Container Apps in Canada Central and Managed Redis in North Central US. Region policy can change; confirm a plan before applying.
- The Container App has public HTTPS ingress for the test. Redis uses TLS and key authentication; its public network setting is enabled because this app is not VNet-integrated. Do not weaken Redis authentication or TLS.
- The Redis access key enters Terraform state and Container Apps' secret configuration. State and saved plans are ignored by Git; never upload or commit them. This short-lived demo uses local state, not a shared production backend.
- This is a fixed-capacity baseline (1 replica). It does not claim Azure autoscaling. The separate earlier 2–5 replica test did not scale on WebSocket connections.
- No budgets are created.

## Run

From this directory, after verifying `az account show` selects the intended subscription:

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=typescale.tfplan
terraform show typescale.tfplan
# Review the plan and its regions/SKU before applying.
terraform apply typescale.tfplan
```

Check `https://$(terraform output -raw app_fqdn)/health/ready`, then run the synthetic WebSocket loader against `/ws` and retain evidence outside Git. For cleanup:

```bash
terraform plan -destroy -out=typescale-destroy.tfplan
terraform show typescale-destroy.tfplan
terraform apply typescale-destroy.tfplan
```

Verify the resource group is gone before removing local state. If deployment fails partway, inspect the state and destroy only this dedicated stack; do not reuse the group for unrelated resources.
