# lifeboat

A minimal Docker sidecar for scheduled backups. Add it to an existing Compose stack. You provide the backup script; lifeboat handles scheduling, retention, and health reporting.

## How it works

1. Add `lifeboat` as a service to your existing `docker-compose.yml`.
2. Mount your backup script to `/scripts/backup.sh`.
3. `runner.sh` invokes `/scripts/backup.sh`.
4. Runner exports `BACKUP_DIR=/backups`. Your script chooses a filename, writes exactly one non-empty regular file in that directory, and prints only that file's basename to stdout.
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

## Releases

Versions are managed by release-please. Merging a normal pull request into `main` creates or updates a versioning PR. Merging that PR creates a SemVer Git tag, and the publish workflow builds and publishes the multi-architecture Docker image to GHCR. No GitHub Release is created.

Use Conventional Commit titles for pull requests and squash-merge them so the PR title becomes the commit subject:

- `fix: ...` creates a patch release.
- `feat: ...` creates a minor release.
- `feat!: ...` or another type with `!` creates a major release.
- `chore: ...`, `docs: ...`, and similar maintenance types do not create a release.

The release workflow requires a repository secret named `MY_RELEASE_PLEASE_TOKEN`. It must be a token that can write repository contents, issues, and pull requests. A personal access token is used so the Docker version tag can trigger the image publishing workflow.

## Bring your own script

Mount any script to `/scripts/backup.sh`. It must choose its output filename, write one file under `/backups`, and print the basename:

```bash
#!/bin/bash
set -euo pipefail

backup_dir="${BACKUP_DIR:-/backups}"
backup_file="${backup_dir}/${BACKUP_PREFIX}_$(date +%Y%m%dT%H%M%S).tar.gz"
tar czf "$backup_file" /path/to/your/data
printf '%s\n' "$(basename "$backup_file")"
```

The script runs as `bash /scripts/backup.sh` - no execute bit required. Runner provides `BACKUP_DIR=/backups`; the fallback makes the script usable outside Lifeboat. Its stdout must contain exactly one basename with no directory separators or extra output. If it exits non-zero, creates anything other than exactly one new non-empty regular file, or returns the wrong filename, the container goes unhealthy.

## Configuration

| Variable | Default | Description |
|---|---|---|
| `SCHEDULE` | `0 3 * * *` | Cron expression for when backups run |
| `TZ` | `UTC` | Timezone for the cron schedule |
| `BACKUP_PREFIX` | `backup` | Safe value exposed to the handler, which may use it in its chosen filename |
| `RETAIN_COUNT` | unset | Keep the N most recent backups |
| `RETAIN_SIZE_MB` | unset | Delete oldest until total size is under N MB |
| `RETAIN_DAYS` | unset | Delete backups older than N days |
| `RUN_ON_START` | `false` | Run a backup immediately on container start, before the first cron tick |

All retention rules are enforced independently — set any combination.

Retention considers every regular file directly under `/backups`, so keep that directory dedicated to backup output.

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

The container is **unhealthy** if the last attempted backup failed (script exited non-zero, or the script did not deliver exactly one new non-empty regular file and return its basename). It recovers automatically on the next successful run.

**Health does not guarantee backup freshness.** A healthy container means the last run succeeded — not that a run has happened recently. Use `SCHEDULE` and `RUN_ON_START` to control timing.

A failed backup leaves existing backups untouched and skips retention pruning.

## Agentic Disclosure
This project was developed and maintained by human authors. Agentic development tools (such as Github Co-Pilot and OpenAI/Codex) have been utilized for continuous architectural and refactoring assistance. All core logic, security boundaries, and code modifications have been reviewed, tested, and verified by humans prior to deployment.
