# Lifeboat Agent Guide

Lifeboat is a Docker sidecar for scheduled backups. The human-facing contract
belongs in `README.md`; this file is for agent behavior and repo handling.

## Project Shape

- `entrypoint.sh` — sets up cron and optionally runs a first backup (`RUN_ON_START`)
- `runner.sh` — called by cron; validates `BACKUP_PREFIX`, invokes `backup.sh`, enforces retention
- `scripts/backup.sh` — sample script; users replace this with their own
- `Dockerfile` — alpine base, copies `entrypoint.sh` + `runner.sh`, no extras
- `docker-compose.yml` — single-service reference example with inline env vars

## Key Contracts

- The handler at `/scripts/backup.sh` must create exactly one new non-empty regular file directly under `/backups` and print only its basename to stdout. `BACKUP_PREFIX` is validated and exported for the handler but does not determine the output filename.
- `runner.sh` exports `BACKUP_DIR=/backups` for the handler. Handlers should use `${BACKUP_DIR:-/backups}` when they can also run standalone.
- `BACKUP_PREFIX` is validated in `runner.sh` before the handler runs. Allowed: letters, numbers, dot, underscore, dash. Rejected: empty, `.`, `..`, anything with `/`, spaces, or shell metacharacters.
- Health flag is `/tmp/backup_failed`. Present = unhealthy. Removed on next successful run.
- Lock file is `/tmp/lifeboat.lock` (flock). Prevents overlapping runs; second invocation exits 0 silently.

## Verification Steps

When making changes, verify with:

```bash
docker compose config
docker build -t lifeboat-check .
docker run --rm \
  -e BACKUP_PREFIX=backup \
  -e RUN_ON_START=true \
  -v /tmp/lifeboat-test:/backups \
  lifeboat-check
ls /tmp/lifeboat-test
```

Test unsafe prefixes fail (runner.sh should exit 1):

```bash
BACKUP_PREFIX="../bad"
BACKUP_PREFIX="bad prefix"
BACKUP_PREFIX="."
BACKUP_PREFIX=".."
```

