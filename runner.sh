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
BACKUP_DIR=/backups
export BACKUP_DIR BACKUP_PREFIX

collect_backup_files() {
  backup_files=()
  local candidate
  while IFS= read -r -d '' candidate; do
    backup_files+=("$candidate")
  done < <(find /backups -maxdepth 1 -type f -print0)
}

find_new_backup_files() {
  new_files=()
  local candidate prior known
  for candidate in "${backup_files[@]}"; do
    known=false
    for prior in "${before_files[@]}"; do
      if [ "$candidate" = "$prior" ]; then
        known=true
        break
      fi
    done
    [ "$known" = false ] && new_files+=("$candidate")
  done
}

remove_files() {
  local file
  for file in "$@"; do
    rm -f -- "$file"
  done
}

find_oldest_backup() {
  oldest_backup=""
  oldest_mtime=""
  local candidate mtime
  for candidate in "${backup_files[@]}"; do
    mtime=$(stat -c %Y "$candidate")
    if [ -z "$oldest_mtime" ] || [ "$mtime" -lt "$oldest_mtime" ]; then
      oldest_backup="$candidate"
      oldest_mtime="$mtime"
    fi
  done
}

echo "[lifeboat] $(date -Iseconds) starting"

collect_backup_files
before_files=("${backup_files[@]}")

handler_output=""
handler_status=0
if handler_output=$(bash /scripts/backup.sh); then
  handler_status=0
else
  handler_status=$?
fi

collect_backup_files
find_new_backup_files

if [ "$handler_status" -ne 0 ]; then
  remove_files "${new_files[@]}"
  touch /tmp/backup_failed
  echo "[lifeboat] ERROR: backup script exited non-zero — container is now unhealthy" >&2
  exit 1
fi

case "$handler_output" in
  "" | "." | ".." | */* | *$'\n'*)
    remove_files "${new_files[@]}"
    touch /tmp/backup_failed
    echo "[lifeboat] ERROR: backup script must return exactly one filename on stdout - container is now unhealthy" >&2
    exit 1
    ;;
esac

BACKUP_OUTPUT="/backups/$handler_output"
if [ "${#new_files[@]}" -ne 1 ] || [ "${new_files[0]:-}" != "$BACKUP_OUTPUT" ] || [ ! -s "$BACKUP_OUTPUT" ]; then
  remove_files "${new_files[@]}"
  touch /tmp/backup_failed
  echo "[lifeboat] ERROR: backup script must create exactly one new non-empty regular file and return its filename - container is now unhealthy" >&2
  exit 1
fi

[ -f /tmp/backup_failed ] && echo "[lifeboat] recovered — container is now healthy"
rm -f /tmp/backup_failed
echo "[lifeboat] success: $BACKUP_OUTPUT ($(du -sh "$BACKUP_OUTPUT" | cut -f1))"

# Each retention rule is evaluated independently (OR semantics: any triggered limit prunes)
# Retention considers every regular file directly under /backups.

if [ -n "${RETAIN_COUNT:-}" ]; then
  collect_backup_files
  while [ "${#backup_files[@]}" -gt "$RETAIN_COUNT" ]; do
    find_oldest_backup
    [ -z "$oldest_backup" ] && break
    rm -v -- "$oldest_backup"
    collect_backup_files
  done
fi

if [ -n "${RETAIN_SIZE_MB:-}" ]; then
  limit_kb=$((RETAIN_SIZE_MB * 1024))
  while [ "$(du -sk /backups | cut -f1)" -gt "$limit_kb" ]; do
    collect_backup_files
    [ "${#backup_files[@]}" -eq 0 ] && break
    find_oldest_backup
    [ -z "$oldest_backup" ] && break
    rm -v -- "$oldest_backup"
    echo "[lifeboat] pruned $oldest_backup (size limit ${RETAIN_SIZE_MB}MB)"
  done
fi

if [ -n "${RETAIN_DAYS:-}" ]; then
  find /backups -maxdepth 1 -type f -mtime +"$RETAIN_DAYS" -print -delete
fi

echo "[lifeboat] done."
