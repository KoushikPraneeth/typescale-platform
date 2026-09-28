# Local TypeScale benchmark evidence

## Environment

- Runtime: local OrbStack Kubernetes, `orbstack` context; not an Azure benchmark.
- App: GitOps-managed `typescale-app` in `typescale-gitops`, image digest `sha256:e1e703adcd2da1f293624d29ba5cec378fe875ef3caf411de4568cc3a0aed222`.
- Scaling: KEDA Prometheus scaler, minimum 2 / maximum 5 replicas, target 8 active WebSocket connections per replica.
- Synthetic load: 40 clients, 5-second ramp, 60-second hold, `--complete-races`; each client submits the shared paragraph after the race starts.
- Evidence: generated JSON/CSV artifacts are local scratch files (`local-race-40.json` and `.csv`) and are not committed because they contain per-client timestamps and are reproducible.

## Results (2026-09-28 UTC)

| Measure | Result |
|---|---:|
| WebSocket clients attempted | 40 |
| Successful connections | 40 / 40 (100%) |
| Failed connections | 0 |
| Players joined | 40 / 40 |
| Race completion | 40 / 40 (100%) |
| Peak concurrent WebSockets | 40 |
| Matchmaking latency, p50 | 3.971 ms |
| Matchmaking latency, p95 | 45.068 ms |
| Matchmaking latency, p99 | 138.505 ms |
| Deployment replicas observed after full-race load | 5 / 5 ready |

Latency is measured from `join_sent_at` to `room_joined_at`; it is not end-to-end race duration. This is a local single-node development cluster result, not a production SLO or cloud result. The benchmark demonstrates the game flow and scale-out under synthetic load; it does not claim resilience to node or Redis failure.

A separate 420-second held-WebSocket run completed 40/40 connections with zero failures and drove KEDA from its two-replica minimum to five replicas. After the clients disconnected and KEDA's cooldown plus HPA scale-down stabilization elapsed, the Deployment returned to 2/2 ready replicas. The completed-race run also observed 5/5 ready replicas, but it began while the long-run scale-down period was still active; it is not the evidence for scale-out.

## Reproduction

From `typescale-app` with the load-test dependencies installed and the local service port-forwarded to `127.0.0.1:8000`:

```bash
python loadtest/websocket_load.py \
  --url ws://127.0.0.1:8000/ws \
  --clients 40 --ramp-seconds 5 --hold-seconds 60 \
  --complete-races \
  --json-out artifacts/local-race-40.json \
  --csv-out artifacts/local-race-40.csv
```
