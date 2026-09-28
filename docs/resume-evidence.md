# TypeScale résumé evidence

These bullets are limited to results already recorded in the linked project evidence. Keep the local Kubernetes and Azure claims separate; they are different environments and different experiments.

## Candidate résumé bullets

- Built a server-authoritative multiplayer typing-race platform with FastAPI/WebSockets and Redis, then verified a 40-client local run with 40/40 race completions and zero connection failures; KEDA scaled the local Deployment from 2 to 5 replicas and back to 2. Evidence: [`local-websocket-races.md`](benchmarks/local-websocket-races.md).
- Provisioned a short-lived Azure Container Apps + Azure Managed Redis stack with Terraform, deployed an immutable GHCR digest, and measured 40/40 completed WebSocket races on one fixed replica (p95 matchmaking 494.673 ms); destroyed the stack after the experiment. Evidence: [`azure-terraform.md`](benchmarks/azure-terraform.md).
- Added PR-gated application tests, container build, strict Trivy scan, Helm validation, immutable image publishing, and Argo CD GitOps promotion for the local platform. Evidence: application and platform CI workflows and repository history.
- Ran a controlled local pod-replacement experiment: 40/40 active WebSockets closed with code 1012 when the port-forward's selected pod was removed; documented why this is not zero-downtime and added a recovery smoke test. Evidence: [`pod-replacement-reliability.md`](benchmarks/pod-replacement-reliability.md).

## Claim boundaries

- Azure autoscaling was **not demonstrated**. The configured Azure 2–5 replica test stayed at two replicas under long-lived WebSockets.
- Do not call the Azure p95 a race-completion latency. It is matchmaking latency from `join_sent_at` to `room_joined_at`.
- Do not claim production availability, zero downtime, 80+ user capacity, cost savings, or a percentage performance improvement from these tests.
- OIDC federation and ACR promotion are not yet completed; don't list those as hands-on project deliverables until separately implemented and verified.
