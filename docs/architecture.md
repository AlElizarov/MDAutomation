# Architecture

## Backend Structure

### Project Layout

The backend project uses a layered structure that separates:

- HTTP API
- business logic
- persistence
- infrastructure
- external integrations

Recommended repository layout:

```text
project-root/
|-- src/
|   `-- app/
|-- alembic/
|-- tests/
|-- docs/
|
|-- Dockerfile
|-- docker-compose.yml
|-- requirements.txt
|-- mkdocs.yml
|-- alembic.ini
|-- .env
|-- .env.example
`-- .gitignore
```

## Application Structure

Primary application code lives inside:

```text
src/app/
```

Recommended structure:

```text
src/app/
|-- main.py
|
|-- api/
|   |-- health.py
|   |-- leads.py
|   `-- bindings.py
|
|-- core/
|   |-- config.py
|   `-- logging.py
|
|-- db/
|   |-- base.py
|   |-- session.py
|   `-- models/
|       |-- lead.py
|       `-- binding.py
|
|-- schemas/
|   |-- lead.py
|   `-- binding.py
|
|-- services/
|   |-- lead_service.py
|   `-- binding_service.py
|
|-- integrations/
|   |-- telegram/
|   |-- vk/
|   `-- max/
|
`-- utils/
```

## Directory Responsibilities

| Directory | Responsibility |
| --- | --- |
| `api/` | HTTP routes and request handling |
| `services/` | Business logic and application workflows |
| `db/models/` | SQLAlchemy ORM persistence models |
| `schemas/` | Pydantic request/response schemas |
| `integrations/` | External messenger adapters and webhook handlers |
| `core/` | Infrastructure configuration, settings, logging |
| `utils/` | Shared utility helpers |
| `tests/` | Automated tests |
| `alembic/` | Database migrations |

## Architectural Rules

### Separation of Concerns

Business logic must not live inside:

- HTTP route handlers
- Telegram/VK/MAX adapters
- database models

Route handlers should:

1. Validate request data.
2. Call services.
3. Return responses.

Messenger integrations should act as transport adapters only.

### Integrations as Adapters

Telegram, VK, and MAX integrations are considered channel adapters.

They are responsible for:

- receiving incoming webhook events;
- extracting transport-specific payloads;
- forwarding normalized data into backend services.

They must not contain:

- lead lifecycle logic;
- business rules;
- persistence orchestration.

Core business behavior must remain channel-independent.

### Persistence Layer

Database models represent persistence structure only.

API schemas and ORM models must remain separated.

Example:

```text
schemas/lead.py     -> API request/response validation
db/models/lead.py   -> database persistence model
```

### Environment Configuration

Environment-specific configuration must be externalized via environment
variables.

Local development uses:

```text
.env
```

Template values are documented in:

```text
.env.example
```

The `.env` file must never be committed to git.

### Migrations

Database schema changes must be managed exclusively through Alembic migrations.

Schema modifications must never be performed manually against environments.

Migration workflow:

```bash
alembic revision --autogenerate -m "description"
alembic upgrade head
```

### Health and Readiness

The backend exposes readiness checks through:

```text
GET /health
```

The endpoint validates:

- application responsiveness;
- database connectivity.

Purpose:

```text
Determine whether the service is ready to process requests.
```

### Long-Term Scalability Goal

The structure is intentionally designed to support:

- multiple communication channels;
- asynchronous processing;
- audit logging;
- background workers;
- CRM integrations;
- scalable deployment environments.

The backend remains the single source of truth for:

- lead lifecycle;
- bindings;
- statuses;
- workflow orchestration.
