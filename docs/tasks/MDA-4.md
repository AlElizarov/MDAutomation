# MDA-4

At the end of this task we must have:

- a running FastAPI application
- a working HTTP endpoint
- automatic Swagger/OpenAPI documentation
- automated app-level tests

## Description

This is the first backend task in the project.

No database or business logic is introduced yet.

The task establishes:

- project structure
- FastAPI runtime
- API testing approach
- OpenAPI/Swagger foundation

The backend must:

- start successfully
- accept HTTP requests
- support automated testing
- expose Swagger/OpenAPI endpoints

## Main endpoint

`GET /health`

Expected response:

```json
{
  "status": "ok"
}
```

## Swagger/OpenAPI endpoints

FastAPI must automatically expose:

- `/docs`
- `/redoc`
- `/openapi.json`

## Automated tests

Must include app-level tests using:

- pytest
- FastAPI TestClient

Required checks:

- `/health` returns 200
- `/docs` available
- `/openapi.json` available
- OpenAPI schema generated correctly

## Explicitly Out of Scope

Do NOT add:

- Docker
- PostgreSQL
- SQLAlchemy
- Alembic
- business entities
- Lead flow
- Telegram/VK/MAX integrations

These are implemented in later MDA tasks.
