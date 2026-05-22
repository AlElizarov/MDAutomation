# MDA-5

Containerize the FastAPI backend application and prepare a reproducible local runtime environment using Docker and Docker Compose.

Add smoke tests to verify that the application container builds successfully, starts correctly, and responds via the health endpoint.

This task establishes the foundation for CI/CD pipelines, deployment portability, and future service orchestration.

## Scope

- Create production-ready Dockerfile for FastAPI app
- Add `.dockerignore`
- Add `docker-compose.yml`
- Ensure app runs inside container on configurable host/port
- Configure environment variable support
- Add container startup documentation
- Add smoke tests for container lifecycle and `/health` endpoint

## Acceptance Criteria

- `docker build` completes successfully
- `docker compose up` starts the backend without errors
- FastAPI app is accessible from host machine
- `GET /health` returns HTTP 200
- Smoke tests validate:
  - image build
  - container startup
  - health endpoint availability
- Documentation includes local Docker run instructions

## Example Verification

```powershell
docker compose up --build
curl http://localhost:8000/health
```

Expected response:

```json
{
  "status": "ok"
}
```

## Deliverables

- `Dockerfile`
- `.dockerignore`
- `docker-compose.yml`
- updated README/setup docs
- smoke test scripts or CI checks

## Dependencies

Depends on: MDA-4

Enables: MDA-6, CI/CD integration, deployment automation
