#!/bin/sh
# Railway wrapper for Prometheus: auth from the first request, retention capped
# to the volume, scrape targets from the environment.
set -eu

DATA=/prometheus
CONF=/etc/prometheus
USER_NAME="${PROMETHEUS_USER:-admin}"

if [ -z "${PROMETHEUS_PASSWORD:-}" ]; then
  echo "FATAL: PROMETHEUS_PASSWORD is not set. Prometheus has no login of its own; refusing to start it open to the internet." >&2
  exit 1
fi

# The volume is mounted root-owned; Prometheus runs as nobody (65534).
chown 65534:65534 "$DATA"

# Basic auth. Prometheus accepts bcrypt hashes only.
HASH="$(bcrypt-hash)"
umask 077
cat > "$CONF/web.yml" <<WEB
basic_auth_users:
  ${USER_NAME}: '${HASH}'
WEB
chown 65534:65534 "$CONF/web.yml"
umask 022

# Retention: time, plus a size cap so the TSDB cannot fill the volume.
# Default cap is 80% of the filesystem Railway mounted (the plan's volume size).
RETENTION_TIME="${RETENTION_TIME:-15d}"
if [ -z "${RETENTION_SIZE:-}" ]; then
  total_kb="$(df -Pk "$DATA" | awk 'NR==2 {print $2}')"
  RETENTION_SIZE="$(( total_kb * 80 / 100 / 1024 ))MB"
fi

# Scrape config. PROMETHEUS_CONFIG replaces it entirely; otherwise build one
# from SCRAPE_TARGETS (comma-separated host:port, e.g. api.railway.internal:3000).
SCRAPE_INTERVAL="${SCRAPE_INTERVAL:-15s}"
METRICS_PATH="${METRICS_PATH:-/metrics}"
if [ -n "${PROMETHEUS_CONFIG:-}" ]; then
  printf '%s\n' "$PROMETHEUS_CONFIG" > "$CONF/prometheus.yml"
  SCRAPE_DESC="PROMETHEUS_CONFIG (custom)"
else
  {
    echo "global:"
    echo "  scrape_interval: ${SCRAPE_INTERVAL}"
    echo "scrape_configs:"
    echo "  - job_name: prometheus"
    echo "    basic_auth:"
    echo "      username: '${USER_NAME}'"
    echo "      password: '${PROMETHEUS_PASSWORD}'"
    echo "    static_configs:"
    echo "      - targets: ['127.0.0.1:${PORT:-9090}']"
    if [ -n "${SCRAPE_TARGETS:-}" ]; then
      echo "  - job_name: railway"
      echo "    metrics_path: '${METRICS_PATH}'"
      echo "    static_configs:"
      echo "      - targets:"
      echo "$SCRAPE_TARGETS" | tr ',' '\n' | while read -r t; do
        t="$(echo "$t" | tr -d ' ')"
        [ -n "$t" ] && echo "          - '$t'"
      done
    fi
  } > "$CONF/prometheus.yml"
  SCRAPE_DESC="${SCRAPE_TARGETS:-none (self only)}"
fi
chmod 600 "$CONF/prometheus.yml"
chown 65534:65534 "$CONF/prometheus.yml"

/bin/promtool check config "$CONF/prometheus.yml" >&2 || { echo "FATAL: generated config failed promtool" >&2; exit 1; }

echo "railway-prometheus: user=${USER_NAME} port=${PORT:-9090} retention.time=${RETENTION_TIME} retention.size=${RETENTION_SIZE} targets=${SCRAPE_DESC}" >&2
echo "railway-prometheus: data dir owner=$(stat -c %u:%g "$DATA") free=$(df -Pk "$DATA" | awk 'NR==2 {print $4}')KB" >&2

exec setuidgid nobody /bin/prometheus \
  --config.file="$CONF/prometheus.yml" \
  --web.config.file="$CONF/web.yml" \
  --storage.tsdb.path="$DATA" \
  --storage.tsdb.retention.time="$RETENTION_TIME" \
  --storage.tsdb.retention.size="$RETENTION_SIZE" \
  --web.listen-address="[::]:${PORT:-9090}" \
  --web.enable-remote-write-receiver \
  "$@"
