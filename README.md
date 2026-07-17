# lifeboat

A minimal Docker sidecar for scheduled backups. Add it to an existing Compose stack. You provide the backup script; lifeboat handles scheduling, retention, and health reporting.

## How it works

1. Add `lifeboat` as a service to your existing `docker-compose.yml`.
2. Mount your backup script to `/scripts/backup.sh`.
3. `runner.sh` sets `$BACKUP_FILE` to a timestamped filename stem under `/backups`.
4. Your script writes one non-empty backup file using `$BACKUP_FILE` as its name or filename stem. Any extension is allowed.
5. Lifeboat enforces your retention policy and marks the container unhealthy if a backup fails.

## Adding to an existing stack

```yaml
services:
  # ... your existing services ...

  lifeboat:
    image: ghcr.io/cakeholedc/lifeboat:latest
    environment:
      SCHEDULE: "0 3 * * *"
      TZ: UTC
      BACKUP_PREFIX: myapp
      RETAIN_COUNT: "10"
    volumes:
      - ./scripts/backup.sh:/scripts/backup.sh:ro
      - ./backups:/backups
    restart: unless-stopped
```

Pin to a specific release instead of `latest` for production use (e.g. `ghcr.io/cakeholedc/lifeboat:v1.0.0`).

To build from source, clone this repo and replace `image:` with `build: .`.

## Bring your own script

Mount any script to `/scripts/backup.sh`. It must write an archive to `$BACKUP_FILE`:

```bash
#!/bin/bash
set -euo pipefail

tar czf "${BACKUP_FILE}.tar.gz" /path/to/your/data
```

The script runs as `bash /scripts/backup.sh` - no execute bit required. If it exits non-zero, or if it does not deliver exactly one non-empty file beginning with `$BACKUP_FILE`, the container goes unhealthy.

## Configuration

| Variable | Default | Description |
|---|---|---|
| `SCHEDULE` | `0 3 * * *` | Cron expression for when backups run |
| `TZ` | `UTC` | Timezone for the cron schedule |
| `BACKUP_PREFIX` | `backup` | Filename prefix - e.g. `myapp` → `myapp_20260616T030000.tar.gz` |
| `RETAIN_COUNT` | unset | Keep the N most recent backups |
| `RETAIN_SIZE_MB` | unset | Delete oldest until total size is under N MB |
| `RETAIN_DAYS` | unset | Delete backups older than N days |
| `RUN_ON_START` | `false` | Run a backup immediately on container start, before the first cron tick |

All retention rules are enforced independently — set any combination.

`BACKUP_PREFIX` must contain only letters, numbers, dots, underscores, and dashes. It cannot be `.` or `..`.

## Local testing

To get a backup immediately without waiting for the cron schedule:

```yaml
environment:
  SCHEDULE: "* * * * *"   # every minute
  RUN_ON_START: "true"    # also run once at startup
```

## Health

```bash
docker compose ps      # healthy / unhealthy at a glance
docker compose logs -f # backup run output
```

The container is **unhealthy** if the last attempted backup failed (script exited non-zero, or the script did not deliver exactly one non-empty file beginning with `$BACKUP_FILE`). It recovers automatically on the next successful run.

**Health does not guarantee backup freshness.** A healthy container means the last run succeeded — not that a run has happened recently. Use `SCHEDULE` and `RUN_ON_START` to control timing.

A failed backup leaves existing backups untouched and skips retention pruning.

## Agentic Disclosure
This project was developed and maintained by human authors. Agentic development tools (such as Github Co-Pilot and OpenAI/Codex) have been utilized for continuous architectural and refactoring assistance. All core logic, security boundaries, and code modifications have been reviewed, tested, and verified by humans prior to deployment.
