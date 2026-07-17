#!/bin/bash
set -euo pipefail

if [ "${BACKUP_DIR:-}" != /backups ]; then
  exit 1
fi

printf 'database backup\n' > "$BACKUP_DIR/backup_handler.db"
printf '%s\n' backup_handler.db
