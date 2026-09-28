# GitHub Actions OIDC → Azure Container Registry proof

**Date:** 2026-09-29 (local)

## What was exercised

- Added a manually dispatched GitHub Actions workflow bound to the `azure-demo` environment with `id-token: write`; no client secret or registry admin account was used.
- Provisioned a temporary Basic Azure Container Registry, a user-assigned managed identity, GitHub's immutable repository/owner-ID subject federation, and a registry-scoped `AcrPush` assignment. The first authentication attempt failed because the initial trust subject used the legacy owner/repository format. GitHub's OIDC customization endpoint and the AADSTS diagnostic showed the immutable-ID subject format; Terraform was corrected to match it in platform PR #12.
- The successful workflow run authenticated through Azure OIDC, copied the already-tested GHCR image `ghcr.io/koushikpraneeth/typescale@sha256:e1e703adcd2da1f293624d29ba5cec378fe875ef3caf411de4568cc3a0aed222`, pushed it under the workflow commit tag, resolved the ACR manifest digest, and pulled it back by digest.
- GitHub Actions run [36474517650](https://github.com/KoushikPraneeth/typescale-platform/actions/runs/36474517650) completed successfully. The remotely queried ACR digest matched the source digest exactly; the digest-addressed Docker pull succeeded.
- Platform PR #11 added the stack/workflow; PR #12 corrected immutable subject matching. Both passed platform validation before merge.

## Cleanup and boundaries

- Terraform destroyed all six resources. Azure returned `false` for the dedicated resource-group existence check and no matching ACR; Terraform state had no remaining entries or outputs.
- Removed the local Terraform state, saved plans, and provider cache after remote deletion verification. Removed all five temporary GitHub repository variables and the `azure-demo` environment (the environment lookup returned 404 afterward).
- This is evidence of keyless OIDC authentication and immutable image publication to a temporary ACR. It does **not** prove deployment from ACR, Azure Container Apps autoscaling, production reliability, or zero cost. The ACR was billable while provisioned; a final Azure Cost Management charge total was not captured.
