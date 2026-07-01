FROM alpine:3.19

RUN apk add --no-cache bash tzdata util-linux

COPY entrypoint.sh /entrypoint.sh
COPY runner.sh /runner.sh
RUN chmod +x /entrypoint.sh /runner.sh

VOLUME /backups

HEALTHCHECK --interval=5m --timeout=5s --start-period=10s --retries=1 \
  CMD test ! -f /tmp/backup_failed

ENTRYPOINT ["/entrypoint.sh"]
