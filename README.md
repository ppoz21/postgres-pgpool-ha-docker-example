# PostgreSQL + Pgpool-II HA Docker Example

This project demonstrates a small PostgreSQL high-availability and read-scaling setup using Docker Compose.

The topology uses four logical hosts:

| Service | Role | Host port |
| --- | --- | --- |
| `postgres-primary` | PostgreSQL primary node, accepts writes | `15433` |
| `postgres-replica` | PostgreSQL standby node, follows the primary through streaming replication | `15434` |
| `pgpool` | Pgpool-II proxy/load balancer, single entry point for clients | `15432` |
| `client` | Temporary `psql` client container used for tests | none |

Client applications should connect to Pgpool, not directly to either PostgreSQL node.

```text
client/app
   |
   v
pgpool:5432
   |
   +--> postgres-primary:5432   writes and some reads
   |
   +--> postgres-replica:5432   read-only traffic
```

## What This Demonstrates

- PostgreSQL streaming replication from one primary to one standby.
- Pgpool-II routing through a separate load-balancer host.
- Read query load balancing across PostgreSQL nodes.
- Continued read/write availability when the replica is stopped.

This is a local lab setup. It intentionally uses trust authentication inside the isolated Docker network to keep the demo focused on replication and load balancing. Do not use this authentication model in production.

## Requirements

- Docker
- Docker Compose v2
- `make` is optional, but recommended for shorter commands

## Start The Cluster

```bash
docker compose up -d --build
```

Or:

```bash
make up
```

Check that all long-running services are healthy:

```bash
docker compose ps
```

Expected services:

- `postgres-primary`
- `postgres-replica`
- `pgpool`

The `client` service is a tool container and only starts when explicitly used.

## Connect Through Pgpool

From the host:

```bash
psql -h localhost -p 15432 -U app_user -d appdb
```

From the bundled client container:

```bash
docker compose run --rm --no-deps client
```

Run a simple query:

```bash
docker compose run --rm --no-deps client -c "SELECT count(*) FROM ha_demo;"
```

## Test Writes Through Pgpool

Insert a row through Pgpool:

```bash
docker compose run --rm --no-deps client -c "INSERT INTO ha_demo (message) VALUES ('written through pgpool');"
```

Or:

```bash
make write
```

The write is routed to the primary node.

## Verify Streaming Replication

Check replication status on the primary:

```bash
docker compose exec postgres-primary psql -U postgres -d appdb -c \
  "SELECT application_name, state, sync_state, replay_lag FROM pg_stat_replication;"
```

Or:

```bash
make replica-status
```

Expected result:

- `application_name` should show the replica connection.
- `state` should be `streaming`.

You can also query the replica directly:

```bash
docker compose exec postgres-replica psql -U postgres -d appdb -c \
  "SELECT pg_is_in_recovery() AS is_replica, count(*) FROM ha_demo;"
```

Expected result:

- `is_replica` should be `t`.
- The row count should include rows inserted through Pgpool.

## Inspect Pgpool Nodes

Ask Pgpool how it sees the PostgreSQL backends:

```bash
docker compose run --rm --no-deps client -c "SHOW pool_nodes;"
```

Or:

```bash
make status
```

Expected result:

- one node with role `primary`
- one node with role `standby`
- both nodes should have `up` status after startup

## Test Read Load Balancing

Run multiple read queries through Pgpool:

```bash
for i in $(seq 1 20); do
  docker compose run --rm --no-deps client -c "SELECT count(*) AS rows FROM ha_demo;"
done
```

Or:

```bash
make read-loop
```

Then inspect Pgpool counters:

```bash
docker compose run --rm --no-deps client -c "SHOW pool_nodes;"
```

The `select_cnt` column should increase on both nodes. That shows Pgpool is distributing read queries.

Diagnostic functions such as `pg_is_in_recovery()` can be routed to the primary by Pgpool, so use a plain read query like `SELECT count(*)` for this load-balancing test.

## Test Replica Failure

Stop the replica:

```bash
docker compose stop postgres-replica
```

Or:

```bash
make stop-replica
```

Give Pgpool a few seconds to detect the change, then inspect nodes:

```bash
docker compose run --rm --no-deps client -c "SHOW pool_nodes;"
```

The replica should eventually be shown as down, while the primary remains up.

Writes through Pgpool should still work:

```bash
docker compose run --rm --no-deps client -c "INSERT INTO ha_demo (message) VALUES ('written while replica is down');"
```

Reads should also still work:

```bash
docker compose run --rm --no-deps client -c "SELECT count(*) FROM ha_demo;"
```

Start the replica again:

```bash
docker compose start postgres-replica
```

Or:

```bash
make start-replica
```

After it catches up, verify that PostgreSQL streaming replication is back:

```bash
make replica-status
```

Pgpool keeps a failed backend detached until it is attached again. Reattach the replica node:

```bash
make attach-replica
```

Then check Pgpool again:

```bash
make status
```

## Useful Commands

Follow all logs:

```bash
docker compose logs -f
```

Follow only Pgpool logs:

```bash
docker compose logs -f pgpool
```

Open a shell-like `psql` session through Pgpool:

```bash
docker compose run --rm --no-deps client
```

Connect directly to the primary from the host:

```bash
psql -h localhost -p 15433 -U postgres -d appdb
```

Connect directly to the replica from the host:

```bash
psql -h localhost -p 15434 -U postgres -d appdb
```

## Reset The Lab

Stop containers but keep data:

```bash
docker compose down
```

Remove containers and PostgreSQL volumes:

```bash
docker compose down -v
```

Or:

```bash
make reset
```

Use the reset command when you want PostgreSQL initialization scripts to run again from scratch.

## Notes And Limitations

- Pgpool is a single load-balancer container in this demo. A production design would usually add a second Pgpool instance plus a virtual IP or another failover mechanism.
- Automatic primary promotion is not configured. If the primary node fails, the standby still has the data, but writes will not continue until failover/promotion is added.
- Trust authentication is used only to keep the local demo compact and easy to inspect.
