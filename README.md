# MDAutomation

Backend platform for accepting, storing, and processing online consultation
requests across communication channels.

## Contents

- [Purpose](#purpose)
- [Architecture](#architecture)
- [Request Processing Flow](#request-processing-flow)
- [Repository Structure](#repository-structure)
- [Key Documentation](#key-documentation)
- [Local Development](#local-development)
- [Database Migrations](#database-migrations)
- [Verification](#verification)
- [Development Workflow](#development-workflow)

## Purpose

MDAutomation provides a unified backend for consultation request handling.

The system is designed to:

- accept consultation requests from landing pages and forms;
- validate and store lead data;
- expose backend health and readiness checks;
- keep business logic independent from transport channels;
- prepare the platform for messenger integrations such as Telegram, VK, and MAX.

## Architecture

The application follows a layered backend architecture.

```text
Landing Page / Form
        |
        v
FastAPI Backend
        |
        v
Application Services
        |
        v
Persistence Layer
        |
        v
PostgreSQL
```

Future messenger integrations are treated as adapters around the core backend:

```text
Messenger Webhook
        |
        v
Integration Adapter
        |
        v
Application Services
```

The main architectural rule is that business behavior belongs in the service
layer. HTTP handlers, messenger adapters, and database models should stay thin
and focused on their own responsibilities.

For detailed architectural rules, project layout, and long-term scalability
goals, see [docs/architecture.md](docs/architecture.md).

## Request Processing Flow

The current request flow is:

1. A user submits a consultation request.
2. The backend receives and validates the request through the HTTP API.
3. Application services apply the lead workflow.
4. Lead data is stored in PostgreSQL.
5. The backend exposes health and readiness information for local and container
   environments.

The platform is structured so future channel binding and messenger-specific
flows can be added without moving business logic into integration code.

## Repository Structure

```text
.
|-- alembic/             Database migration runtime and versions
|-- docs/                Project documentation
|-- scripts/             Grouped local development, CI, Docker, and migration helpers
|-- src/                 Application source code
|   `-- app/
|-- tests/               Automated tests
|-- docker-compose.yml   Local backend and PostgreSQL environment
|-- Dockerfile           Backend container image
|-- mkdocs.yml           Documentation site configuration
`-- requirements.txt     Python dependencies
```

## Key Documentation

- [Architecture](docs/architecture.md) describes application layers,
  responsibility boundaries, integration rules, and scalability goals.
- [API](docs/api.md) describes the current FastAPI endpoints and interactive
  API documentation locations.
- [Database](docs/database.md) describes PostgreSQL, SQLAlchemy, Alembic,
  persistence, schema management, and recovery commands.
- [Conventions](docs/conventions.md) describes repository and development
  conventions.
- [Task documentation](docs/tasks) contains implementation context for tracked
  project tasks.

## Local Development

Install project dependencies:

```powershell
.\scripts\dev\install_deps.ps1
```

Run the backend and PostgreSQL with Docker Compose:

```powershell
.\scripts\dev\run_server.ps1
```

Open the Docker-backed backend in a separate PowerShell window:

```powershell
.\scripts\dev\run_server.ps1 -NewWindow
```

Check the backend health endpoint:

```powershell
curl http://localhost:8000/health
```

Interactive FastAPI documentation is available from the running application:

- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`
- OpenAPI schema: `http://localhost:8000/openapi.json`

See [docs/api.md](docs/api.md) for API details.

## Database Migrations

Database schema changes are managed with Alembic.

Apply migrations against a local PostgreSQL database:

```powershell
$env:DATABASE_URL = "postgresql://mda_user:<local-password>@localhost:5432/mda_dev"
.\scripts\db\migrate.ps1
```

Apply migrations inside Docker Compose:

```powershell
docker compose up -d
docker compose exec backend python -m alembic upgrade head
```

See [docs/database.md](docs/database.md) for the database schema, persistence
model, migration workflow, rollback commands, and recovery details.

## Verification

Run automated tests:

```powershell
.\scripts\dev\test.ps1
```

Run the full local CI check:

```powershell
.\scripts\ci\local-ci.ps1
```

Build the documentation site:

```powershell
.\scripts\docs\build_docs.ps1
```

Run the Docker smoke test:

```powershell
.\scripts\docker\smoke-docker.ps1
```

## Development Workflow

Jira is used for roadmap, epics, backlog, and project management.

Technical implementation context is stored in [docs/tasks](docs/tasks).
Task files should be committed together with the code they describe.

Before opening a pull request, run:

```powershell
.\scripts\ci\local-ci.ps1
```
