#!/usr/bin/env bats

setup() {
  image="ghcr.io/cakeholedc/lifeboat:latest"

  backup_dir="$(mktemp -d /tmp/lifeboat-runner-test.XXXXXX)"
}

teardown() {
  rm -rf "$backup_dir"
}

@test "accepts a backup extension selected by the script and retains it" {
  run docker run --rm \
    --entrypoint /bin/bash \
    -e BACKUP_PREFIX=backup \
    -e RETAIN_COUNT=1 \
    -v "$BATS_TEST_DIRNAME/../runner.sh:/runner.sh:ro" \
    -v "$BATS_TEST_DIRNAME/fixtures/backup-db.sh:/scripts/backup.sh:ro" \
    -v "$backup_dir:/backups" \
    "$image" -c '
      printf "old database backup\\n" > /backups/backup_20200101T000000.db
      printf "old zip backup\\n" > /backups/backup_20200102T000000.zip
      touch -t 202001010000 /backups/backup_20200101T000000.db /backups/backup_20200102T000000.zip
      bash /runner.sh
      [ "$(find /backups -maxdepth 1 -type f -name "*.db" | wc -l | tr -d " ")" -eq 1 ]
      [ -s /backups/backup_handler.db ]
      [ ! -e /backups/backup_20200101T000000.db ]
      [ ! -e /backups/backup_20200102T000000.zip ]
      [ "$(find /backups -maxdepth 1 -type f -name "*.tar.gz" | wc -l | tr -d " ")" -eq 0 ]
    '

  [ "$status" -eq 0 ]
}

@test "rejects more than one new backup file" {
  run docker run --rm \
    --entrypoint /bin/bash \
    -e BACKUP_PREFIX=backup \
    -v "$BATS_TEST_DIRNAME/../runner.sh:/runner.sh:ro" \
    -v "$BATS_TEST_DIRNAME/fixtures/backup-two-files.sh:/scripts/backup.sh:ro" \
    -v "$backup_dir:/backups" \
    "$image" -c '
      bash /runner.sh
    '

  [ "$status" -ne 0 ]
  [ ! -e "$backup_dir/first.db" ]
  [ ! -e "$backup_dir/second.db" ]
}
