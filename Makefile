COMPOSE := docker compose
CLIENT := $(COMPOSE) run --rm --no-deps client

.PHONY: up down reset logs ps status write read read-loop replica-status stop-replica start-replica attach-replica

up:
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

reset:
	$(COMPOSE) down -v

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

status:
	$(CLIENT) -c "SHOW pool_nodes;"

write:
	$(CLIENT) -c "INSERT INTO ha_demo (message) VALUES ('inserted through pgpool at ' || now());"

read:
	$(CLIENT) -c "SELECT count(*) AS rows FROM ha_demo;"

read-loop:
	for i in $$(seq 1 20); do $(CLIENT) -c "SELECT count(*) AS rows FROM ha_demo;"; done

replica-status:
	$(COMPOSE) exec postgres-primary psql -U postgres -d appdb -c "SELECT application_name, state, sync_state, replay_lag FROM pg_stat_replication;"

stop-replica:
	$(COMPOSE) stop postgres-replica

start-replica:
	$(COMPOSE) start postgres-replica

attach-replica:
	$(COMPOSE) exec -e PCPPASSFILE=/tmp/pcppass pgpool sh -c 'printf "localhost:9898:pgpool:pgpool_admin\n" > /tmp/pcppass && chmod 600 /tmp/pcppass && pcp_attach_node -h localhost -p 9898 -U pgpool -n 1 -w'
