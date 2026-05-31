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
|   |-- payments_webhooks.py
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
|       |-- payment.py
|       `-- binding.py
|
|-- schemas/
|   |-- lead.py
|   |-- payment.py
|   `-- binding.py
|
|-- services/
|   |-- lead_service.py
|   |-- payment_service.py
|   `-- binding_service.py
|
|-- payments/
|   `-- providers/
|       |-- base.py
|       `-- test_provider.py
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
| `payments/providers/` | Payment provider adapter interfaces and implementations |
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

Payment webhook routes follow the same rule: they validate transport payloads,
normalize provider identifiers, and call services. Payment lifecycle decisions
must stay in `services/`.

Webhook idempotency and strict payment status transition validation are not part
of the current test provider implementation. They should be introduced with real
provider integrations, where retry semantics, signatures, provider event ids,
and terminal state rules are known.

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

### Payment Providers as Adapters

Payment providers are integrated through adapter classes. `POST /leads` creates
a local Payment, calls `PaymentProviderAdapter.create_payment(...)`, stores the
returned `provider_payment_id` and `payment_url`, and only then returns the URL
to the frontend.

The test provider is intentionally implemented through the same boundary as
future real providers. Its `provider_payment_id` is distinct from internal
`Payment.id`.

Provider selection currently uses the test provider directly from the Lead
creation service. This should move behind provider factory/configuration when
additional providers are introduced.

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
- payment lifecycle;
- bindings;
- statuses;
- workflow orchestration.
