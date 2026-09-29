# TypeScale résumé evidence

These bullets are limited to results already recorded in the linked project evidence. Keep the local Kubernetes and Azure claims separate; they are different environments and different experiments.

## Candidate résumé bullets

- Prepared TypeScale app/chart `1.0.0` and revalidated the local GitOps deployment with its immutable image digest: 40/40 WebSocket clients completed races, with zero connection failures or post-join disconnects and matchmaking latency p50/p95/p99 of 3.971/19.275/91.158 ms. HPA scaled from 2 to 5 during the run, then returned 5→4→3→2 after the active metric reached zero; a separate 420-second held-socket run provides sustained-load evidence. Evidence: [`local-websocket-races.md`](benchmarks/local-websocket-races.md).
- Provisioned a short-lived Azure Container Apps + Azure Managed Redis stack with Terraform, deployed an immutable GHCR digest, and measured 40/40 completed WebSocket races on one fixed replica (p95 matchmaking 494.673 ms); destroyed the stack after the experiment. Evidence: [`azure-terraform.md`](benchmarks/azure-terraform.md).
- Built PR-gated application tests, container build, strict Trivy scan, Helm validation, immutable image publishing, and Argo CD GitOps promotion for the local platform. Evidence: application and platform CI workflows and repository history.
- Implemented keyless GitHub Actions → Azure OIDC authentication with registry-scoped `AcrPush`, then published a tested immutable GHCR image to a temporary ACR and verified pull by digest; destroyed the registry/identity and removed temporary GitHub configuration afterward. Evidence: [`azure-oidc-acr.md`](benchmarks/azure-oidc-acr.md).
- Ran a controlled local pod-replacement experiment: 40/40 active WebSockets closed with code 1012 when the port-forward's selected pod was removed; documented why this is not zero-downtime and added a recovery smoke test. Evidence: [`pod-replacement-reliability.md`](benchmarks/pod-replacement-reliability.md).

## Claim boundaries

- Azure autoscaling was **not demonstrated**. The configured Azure 2–5 replica test stayed at two replicas under long-lived WebSockets.
- Do not call the Azure p95 a race-completion latency. It is matchmaking latency from `join_sent_at` to `room_joined_at`.
- Do not claim production availability, zero downtime, 80+ user capacity, cost savings, a percentage performance improvement, or a zero Azure bill from these tests.
- The OIDC/ACR proof was temporary image publication only; it did not deploy an Azure workload. Its Azure charges were not separately audited; see [`azure-oidc-acr.md`](benchmarks/azure-oidc-acr.md).
