#!/bin/bash
set -euo pipefail

case "$BACKUP_FILE" in
  *.tar.gz) exit 1 ;;
esac

printf 'database backup\n' > "${BACKUP_FILE}.db"
