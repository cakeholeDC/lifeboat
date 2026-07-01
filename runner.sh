#!/bin/bash
set -euo pipefail

exec 9>/tmp/lifeboat.lock
if ! flock -n 9; then
  echo "[lifeboat] previous backup still running, skipping"
  exit 0
fi

if [ ! -f /scripts/backup.sh ]; then
  touch /tmp/backup_failed
  echo "[lifeboat] ERROR: no backup script found at /scripts/backup.sh — mount one and restart" >&2
  exit 1
fi

: "${BACKUP_PREFIX:=backup}"
# Validate prefix: required, safe chars only, reject . and ..
case "$BACKUP_PREFIX" in
  "" | "." | "..")
    touch /tmp/backup_failed
    echo "[lifeboat] ERROR: BACKUP_PREFIX='${BACKUP_PREFIX}' is not allowed" >&2
    exit 1
    ;;
  *[^A-Za-z0-9._-]*)
    touch /tmp/backup_failed
    echo "[lifeboat] ERROR: BACKUP_PREFIX='${BACKUP_PREFIX}' contains illegal characters (allowed: letters, numbers, dot, underscore, dash)" >&2
    exit 1
    ;;
esac
BACKUP_FILE="/backups/${BACKUP_PREFIX}_$(date +%Y%m%dT%H%M%S).tar.gz"
export BACKUP_FILE

echo "[lifeboat] $(date -Iseconds) starting → $BACKUP_FILE"

if bash /scripts/backup.sh; then
  if [ ! -s "$BACKUP_FILE" ]; then
    rm -f "$BACKUP_FILE"
    touch /tmp/backup_failed
    echo "[lifeboat] ERROR: backup script exited 0 but $BACKUP_FILE is missing or empty — container is now unhealthy" >&2
    exit 1
  fi
  [ -f /tmp/backup_failed ] && echo "[lifeboat] recovered — container is now healthy"
  rm -f /tmp/backup_failed
  echo "[lifeboat] success: $BACKUP_FILE ($(du -sh "$BACKUP_FILE" | cut -f1))"
else
  rm -f "$BACKUP_FILE"
  touch /tmp/backup_failed
  echo "[lifeboat] ERROR: backup script exited non-zero — container is now unhealthy" >&2
  exit 1
fi

# Each retention rule is evaluated independently (OR semantics: any triggered limit prunes)
# Retention only considers files matching the backup filename pattern — stray files are ignored.
BACKUP_PATTERN="${BACKUP_PREFIX}_*.tar.gz"

if [ -n "${RETAIN_COUNT:-}" ]; then
  # note: ls -t is safe here since we control the filenames (no spaces, no newlines)
  # shellcheck disable=SC2012,SC2086
  ls -1t /backups/${BACKUP_PATTERN} 2>/dev/null | tail -n +$((RETAIN_COUNT + 1)) | xargs -I{} rm -v {}
fi

if [ -n "${RETAIN_SIZE_MB:-}" ]; then
  limit_kb=$((RETAIN_SIZE_MB * 1024))
  while [ "$(du -sk /backups | cut -f1)" -gt "$limit_kb" ]; do
    # shellcheck disable=SC2012,SC2086
    oldest=$(ls -1t /backups/${BACKUP_PATTERN} 2>/dev/null | tail -1)
    [ -z "$oldest" ] && break
    rm -v "$oldest"
    echo "[lifeboat] pruned $oldest (size limit ${RETAIN_SIZE_MB}MB)"
  done
fi

if [ -n "${RETAIN_DAYS:-}" ]; then
  find /backups -maxdepth 1 -name "${BACKUP_PATTERN}" -mtime +"$RETAIN_DAYS" -print -delete
fi

echo "[lifeboat] done."
