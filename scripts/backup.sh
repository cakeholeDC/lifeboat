#!/bin/bash
# Sample backup script — replace with your own.
# Contract: write your archive to exactly $BACKUP_FILE.
set -euo pipefail

# Mock: create a tarball that records its own origin and timestamp.
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

cat > "$tmpdir/manifest.txt" <<EOF
source: lifeboat sample backup script
timestamp: $(date -Iseconds)
backup_file: $BACKUP_FILE
EOF

tar czf "$BACKUP_FILE" -C "$tmpdir" manifest.txt
echo "[backup.sh] wrote mock archive → $BACKUP_FILE"
