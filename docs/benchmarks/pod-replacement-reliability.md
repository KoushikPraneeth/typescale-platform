# TypeScale pod-replacement reliability experiment

## Setup

- Environment: local OrbStack Kubernetes, not Azure.
- Clients connected through `kubectl port-forward service/typescale-app 8000:80` to the GitOps-managed app.
- 40 WebSocket clients established connections and stayed open while one application pod backing that port-forward was deleted. KEDA observed load during the experiment and scaled the Deployment from its two-replica minimum to five replicas.
- The load generator now records `unexpected_disconnects` separately from initial connection failures.

## Observed result

| Measure | Result |
|---|---:|
| Initial connections | 40 / 40 |
| Unexpected disconnects after pod deletion | 40 / 40 |
| WebSocket close reason | `1012 (service restart)` |
| Races completed | 0 / 40 |
| Deployment after replacement/scale-up | 5 replicas ready |
| Recovery smoke test after restarting port-forward | 2 / 2 clients completed a race; 0 unexpected disconnects |

The port-forward process itself reported `error: lost connection to pod` because its selected backing pod was deleted. Kubernetes documents `kubectl port-forward` as forwarding to a selected pod, not as a production load balancer. Therefore this experiment proves that existing WebSockets on a terminated pod do not transparently migrate, and that the port-forward must be restarted after its backing pod disappears. It does **not** measure production ingress distribution across several pods, prove whole-cluster unavailability, or test client reconnection. The synthetic clients do not reconnect.

## Engineering takeaway

The application can re-create pods and return to readiness, but WebSocket TCP sessions are bound to their original pod and are lost when that pod terminates. A production-grade mitigation would require explicit client reconnect/resume semantics and a defined race-state recovery policy; this run does not verify either. Keep zero-downtime and session-continuity claims out of the résumé.

Per-client JSON/CSV are local scratch artifacts (`local-disruption-40.json` and `.csv`) and are not committed. Reproduction: run 40 clients through a service port-forward for 120 seconds, delete the selected backing app pod after all clients join, and inspect the `unexpected_disconnects` summary. Avoid force-deleting workloads outside this controlled local test.
