# Terraform-provisioned Azure benchmark

## Infrastructure and deployment

A short-lived, fixed-capacity Azure Container Apps stack was created with Terraform from `deploy/azure/terraform/` and destroyed after the experiment. Azure Student subscription policies required the app environment in Canada Central and Azure Managed Redis in North Central US.

- Terraform CLI 1.16.3; AzureRM provider 4.81.0.
- One dedicated resource group, Container Apps environment, Container App, and Azure Managed Redis database.
- Azure Managed Redis `Balanced_B0`, `NoCluster`, TLS-encrypted protocol, key authentication.
- Container App: 0.5 vCPU, 1 GiB, fixed minimum/maximum of one replica, public HTTPS ingress with WebSockets.
- Image pinned to `ghcr.io/koushikpraneeth/typescale@sha256:e1e703adcd2da1f293624d29ba5cec378fe875ef3caf411de4568cc3a0aed222`.
- The Redis URL uses a Terraform-managed secret. Local Terraform state therefore contains sensitive data and remains ignored/unpublished; it was removed only after destroy verification.
- No Azure budget was created. This document makes no zero-cost claim.

Terraform created four resources. The apply log recorded the resource group in 28 s, Container Apps environment in 1m13s, Managed Redis in 7m48s, and Container App in 40s (Redis and environment provisioned concurrently). Both live and ready endpoints returned HTTP 200; Terraform subsequently reported no configuration changes after provider-default normalization was handled.

## Completed-race benchmark (2026-09-28 UTC artifact time)

Forty synthetic clients ramped over five seconds, joined matchmaking, submitted the complete shared prompt after race start, and remained connected for 60 seconds. This run verifies gameplay completion on Azure, unlike the earlier join-only evidence.

| Measure | Result |
|---|---:|
| Connection attempts / successful | 40 / 40 |
| Connection failures | 0 |
| Joined players | 40 / 40 |
| Completed players | 40 / 40 (100%) |
| Peak concurrent WebSockets | 40 |
| Replicas configured / observed | 1 / 1 |
| Matchmaking latency p50 | 314.826 ms |
| Matchmaking latency p95 | 494.673 ms |
| Matchmaking latency p99 | 539.693 ms |

Latency is measured from `join_sent_at` to `room_joined_at`, excluding the WebSocket handshake and race duration. These are results from one bounded synthetic run, not an SLO or general capacity guarantee. The JSON/CSV per-client evidence files are local scratch artifacts (`azure-terraform-race-40.json` and `.csv`) and are not committed because the benchmark is reproducible.

A post-update smoke test after applying URL-encoded Redis credentials completed a two-client race 2/2, and readiness remained HTTP 200.

## Scaling and limitations

This Terraform configuration deliberately uses fixed capacity: `min_replicas = 1`, `max_replicas = 1`. Earlier Container Apps testing configured 2–5 replicas but remained at two under 40 long-lived WebSockets. Do not claim Azure autoscaling from configured limits. Local OrbStack KEDA evidence is separately documented in [`local-websocket-races.md`](local-websocket-races.md).

## Teardown

`terraform plan -destroy` / `terraform apply` removed the stack. Read-back verified the dedicated resource group was not found, Azure Resource Manager returned no resources with the `typescale-tf` name, and the public-IP query returned no TypeScale entries. Terraform state and saved plans were deleted only after this verification because state had held the Redis access key. Local Terraform format/init/validate then passed from the clean configuration. Azure cost data was not obtained in this run; Azure billing may lag, so no total-cost or zero-cost claim is made.
