FROM debian:bookworm-slim

ARG PCP_USER=pgpool
ARG PCP_PASSWORD=pgpool_admin

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        pgpool2 \
        postgresql-client \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --system pgpool \
    && useradd --system --gid pgpool --home-dir /var/lib/pgpool --create-home pgpool \
    && mkdir -p /var/run/pgpool /var/log/pgpool \
    && chown -R pgpool:pgpool /var/run/pgpool /var/log/pgpool /var/lib/pgpool

COPY pgpool.conf /etc/pgpool2/pgpool.conf
COPY pool_hba.conf /etc/pgpool2/pool_hba.conf

RUN touch /etc/pgpool2/pool_passwd \
    && printf "%s:%s\n" "$PCP_USER" "$(pg_md5 "$PCP_PASSWORD")" > /etc/pgpool2/pcp.conf \
    && chown -R pgpool:pgpool /etc/pgpool2 \
    && chmod 600 /etc/pgpool2/pool_passwd /etc/pgpool2/pcp.conf

USER pgpool
EXPOSE 5432 9898

CMD ["pgpool", "-n", "-f", "/etc/pgpool2/pgpool.conf", "-a", "/etc/pgpool2/pool_hba.conf", "-F", "/etc/pgpool2/pcp.conf"]
