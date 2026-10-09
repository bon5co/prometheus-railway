# prometheus-railway

Prometheus 3.15.0 packaged for a one-click Railway deploy.

Differences from running the stock `prom/prometheus` image on Railway:

- **Login from the first request.** Stock Prometheus has no authentication, so a Railway public domain
  exposes the query API, the config and every scrape target to the internet. This image builds a
  bcrypt `web.config.file` at boot from `PROMETHEUS_PASSWORD` (and `PROMETHEUS_USER`, default `admin`)
  and refuses to start without a password.
- **Retention cannot fill the volume.** `--storage.tsdb.retention.time` defaults to 15d and
  `--storage.tsdb.retention.size` defaults to 80% of the filesystem Railway mounted, read at boot.
- **Scrape targets from the environment.** `SCRAPE_TARGETS=api.railway.internal:3000,db.railway.internal:9187`
  (optionally `METRICS_PATH`, `SCRAPE_INTERVAL`), or a whole `PROMETHEUS_CONFIG` YAML.
- **Volume ownership handled.** The entrypoint chowns the root-owned mount and drops to `nobody`.
- Listens on Railway's injected `$PORT`, dual-stack, so private networking works.

The upstream image is pinned by digest in the `Dockerfile`.

## Variables

| Name | Default | Meaning |
|---|---|---|
| `PROMETHEUS_PASSWORD` | required | Basic-auth password (max 72 bytes) |
| `PROMETHEUS_USER` | `admin` | Basic-auth user |
| `SCRAPE_TARGETS` | none | Comma-separated `host:port` list |
| `METRICS_PATH` | `/metrics` | Path scraped on those targets |
| `SCRAPE_INTERVAL` | `15s` | Global scrape interval |
| `PROMETHEUS_CONFIG` | unset | Full `prometheus.yml`, replaces the generated one |
| `RETENTION_TIME` | `15d` | TSDB retention time |
| `RETENTION_SIZE` | 80% of volume | TSDB size cap, e.g. `3GB` |

Mount a volume at `/prometheus`. Extra arguments are passed through to Prometheus.
