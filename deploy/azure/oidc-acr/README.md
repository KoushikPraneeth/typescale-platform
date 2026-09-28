# Short-lived GitHub OIDC to Azure Container Registry proof

This stack creates a temporary resource group, Basic ACR (admin account disabled), user-assigned managed identity, a federated credential scoped to the `azure-demo` GitHub Actions environment, and the narrow `AcrPush` role on that registry. It stores no client secret.

## Provision

Run from this directory with the intended Azure subscription selected:

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan -out=oidc-acr.tfplan
terraform show oidc-acr.tfplan
terraform apply oidc-acr.tfplan
```

The deployment requires permission to create role assignments at the new registry scope. If that permission is denied, stop; do not broaden the role to subscription-level Contributor.

## Configure GitHub

Create the repository environment named `azure-demo`, then add the Terraform outputs as **repository variables** (these are identifiers, not secrets):

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_ACR_NAME`
- `AZURE_ACR_LOGIN_SERVER`

The workflow runs only on `workflow_dispatch` in that environment, requests a short-lived OIDC token, imports the already-tested immutable GHCR image by pulling and retagging it, pushes to ACR, reads the registry digest, and pulls back by that digest. The registry tag is the GitHub commit SHA; the digest is the immutable deployment reference.

Verify the workflow summary and the manifest digest in ACR. This workflow proves OIDC-authenticated image publication only; it does not deploy a Container App using the ACR digest.

## Destroy

After the workflow and evidence capture, destroy the entire resource group:

```bash
terraform plan -destroy -out=oidc-acr-destroy.tfplan
terraform show oidc-acr-destroy.tfplan
terraform apply oidc-acr-destroy.tfplan
```

Verify the group and registry are gone, remove GitHub repository variables and the unused `azure-demo` environment, then remove local state/plans. Never commit `.tfstate` or saved plans. No budget is created; ACR is billable while it exists.
