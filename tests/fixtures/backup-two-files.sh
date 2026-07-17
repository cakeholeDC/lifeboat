#!/bin/bash
set -euo pipefail

printf 'first backup\n' > "$BACKUP_DIR/first.db"
printf 'second backup\n' > "$BACKUP_DIR/second.db"
printf '%s\n' first.db
