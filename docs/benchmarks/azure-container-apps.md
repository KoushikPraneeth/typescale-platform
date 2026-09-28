# Azure Container Apps benchmark

This document records the short-lived Azure validation run. It is evidence, not a claim that Azure is the permanent TypeScale runtime.

## Deployment

| Item | Result |
|---|---|
| Hosting | Azure Container Apps |
| Container Apps region | Canada Central |
| Redis | Azure Managed Redis, North Central US |
| Redis database mode | `NoCluster`, TLS, port `10000` |
| Image | `ghcr.io/koushikpraneeth/typescale:ff7e373...` |
| Fixed-capacity run | 2 replicas, max 2 |
| Autoscale-configured run | 2 minimum, 5 maximum |
| Ingress | HTTPS and WebSockets |

The Azure Student subscription rejected `centralindia` and `eastus` under its allowed-region policy. The allowed-region policy was queried directly rather than guessing.

## Acceptance results

The first deployment attempt produced `0/20` WebSocket joins. The failure was not treated as a success. The Redis database was recreated with `NoCluster` because the application uses a standard Redis client rather than a Redis Cluster client. The corrected run then passed the staged checks:

| Test | Result |
|---|---:|
| Health live | HTTP 200 |
| Health ready | HTTP 200 |
| One WebSocket client | 1/1 |
| Two clients | 2/2 |
| Twenty clients | 20/20 |
| Forty clients | 40/40 |
| Fixed-capacity replicas | 2 |
| WebSocket failures | 0 |

## Forty-client measurement

The measured fixed-capacity run held 40 WebSockets for 45 seconds with a bounded ramp:

```text
attempted:                 40
successful connections:    40
success rate:              100%
peak concurrent WebSockets: 40
join latency p50:          1851.717 ms
join latency p95:          1958.932 ms
join latency p99:          1990.263 ms
failures:                  0
```

This loader measures joining and holds the sockets. It does not yet drive typed text to completion, so `completion_rate` is intentionally not used as a race-completion claim.

A second 40-client run with `minReplicas=2` and `maxReplicas=5` also achieved `40/40`, with p50 `1824.940 ms`, p95 `1914.683 ms`, and p99 `1926.751 ms`. The Container Apps HTTP scaler remained at two replicas during this WebSocket-only test; no Azure scale-up claim is made. This is an important platform limitation to investigate before claiming cloud autoscaling.

## Teardown

The temporary resource group was deleted after the run. The deletion was verified by polling Azure until the group no longer existed. The deployment used no long-lived credentials in the repository.

## Artifacts

The local JSON and CSV results contain one row per client and are intentionally not committed. The load generator can reproduce them with:

```bash
python loadtest/websocket_load.py \
  --url wss://<container-app-fqdn>/ws \
  --clients 40 \
  --hold-seconds 45 \
  --ramp-seconds 8 \
  --json-out artifacts/azure-40.json \
  --csv-out artifacts/azure-40.csv
```
