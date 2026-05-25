# MDA-7

Configure persistent PostgreSQL storage and verify that application data survives container restarts and environment recreation.

This task ensures the backend storage layer is durable and resilient to routine Docker lifecycle operations such as restart, stop/start, and container recreation.

The goal is to prevent accidental data loss during local development and future deployment workflows.

## Scope

- Add persistent Docker volume for PostgreSQL.
- Configure PostgreSQL data directory persistence.
- Verify database durability across container restarts.
- Verify persistence after Docker Compose recreation.
- Add restart resilience smoke/integration tests.
- Document persistence behavior and recovery workflow.

## Functional Requirements

### Persistent Storage

PostgreSQL must store data in a named Docker volume.

Example:

```yaml
services:
  db:
    image: postgres:16
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

### Restart Resilience

Data must survive:

- `docker compose restart`
- `docker compose down`
- `docker compose up`
- backend container recreation

### Persistence Validation

Tests must verify:

- a record can be created;
- PostgreSQL container can be restarted;
- the record still exists afterward.

Example verification flow:

```bash
docker compose up -d
# create test record
docker compose restart db
# verify record still exists
```

## Acceptance Criteria

- PostgreSQL uses persistent Docker volume storage.
- Database data survives PostgreSQL container restart.
- Database data survives Docker Compose recreation.
- Persistence checks are automated through smoke/integration tests.
- Documentation explains:
  - persistent volumes;
  - restart behavior;
  - cleanup/reset workflow.

## Deliverables

- Updated `docker-compose.yml`.
- Persistent Docker volume configuration.
- Persistence smoke/integration tests.
- Updated setup and recovery documentation.
