#!/bin/bash
# Sample backup script — replace with your own.
# Contract: write exactly one backup file under /backups and print its basename.
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/backups}"
backup_file="${BACKUP_DIR}/${BACKUP_PREFIX}_$(date +%Y%m%dT%H%M%S).tar.gz"

# Mock: create a tarball that records its own origin and timestamp.
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

cat > "$tmpdir/manifest.txt" <<EOF
source: lifeboat sample backup script
timestamp: $(date -Iseconds)
backup_file: $backup_file
EOF

tar czf "$backup_file" -C "$tmpdir" manifest.txt
printf '%s\n' "$(basename "$backup_file")"
