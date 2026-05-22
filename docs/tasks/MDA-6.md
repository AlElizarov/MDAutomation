# MDA-6: PostgreSQL Connectivity and Readiness Checks

Integrate PostgreSQL into the backend application and implement database
readiness checks.

The backend must establish and manage PostgreSQL connections through a dedicated
connectivity layer and expose an HTTP endpoint that verifies the application is
ready to serve requests with all required dependencies available.

This task transitions the project from a stateless FastAPI prototype to a
persistent backend service.

## Scope

- Add PostgreSQL service to Docker Compose.
- Configure database connection through environment variables.
- Introduce SQLAlchemy engine and session management.
- Add reusable DB session dependency for FastAPI.
- Implement readiness health endpoint with database connectivity validation.
- Add startup and connectivity tests.
- Ensure graceful handling of database unavailability.

## Functional Requirements

### PostgreSQL Runtime

- PostgreSQL runs as part of local Docker environment.
- Backend connects using configurable `DATABASE_URL`.

Example:

```text
DATABASE_URL=postgresql://mda_user:secret@db:5432/mda
```

### Connectivity Layer

Implement:

- SQLAlchemy engine.
- Session factory.
- Dependency injection for DB sessions.

Example:

```python
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine)
```

### Readiness Endpoint

Endpoint:

```http
GET /health
```

Purpose:

- Verify the application can successfully interact with PostgreSQL.
- Confirm service readiness for request processing.

The endpoint must execute a lightweight query:

```sql
SELECT 1;
```

## Expected Responses

Healthy state:

```json
{
  "status": "ok",
  "database": "connected"
}
```

Degraded state:

```json
{
  "status": "degraded",
  "database": "unavailable"
}
```

Optionally return HTTP 503 Service Unavailable when DB connectivity fails.

## Acceptance Criteria

- PostgreSQL starts successfully in Docker Compose.
- FastAPI connects to PostgreSQL.
- Connection configuration is environment-driven.
- `/health` validates database readiness.
- DB connectivity failures are handled gracefully.
- Integration/smoke tests cover:
  - DB startup.
  - Successful connection.
  - Failed connection scenarios.

## Deliverables

- Updated `docker-compose.yml`.
- DB configuration module.
- SQLAlchemy session layer.
- Readiness health endpoint.
- Integration/smoke tests.
- Updated setup documentation.
