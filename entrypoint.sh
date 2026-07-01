#!/bin/bash
set -e

: "${SCHEDULE:=0 3 * * *}"

if [ -n "${TZ:-}" ]; then
  ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
  echo "$TZ" > /etc/timezone
fi

# Redirect cron job output to Docker logs via PID 1's stdout/stderr
echo "$SCHEDULE /runner.sh >> /proc/1/fd/1 2>&1" > /etc/crontabs/root

echo "[lifeboat] schedule: $SCHEDULE | tz: ${TZ:-UTC}"

if [ "${RUN_ON_START:-false}" = "true" ]; then
  echo "[lifeboat] RUN_ON_START: running backup now"
  /runner.sh
fi

exec crond -f -d 6
