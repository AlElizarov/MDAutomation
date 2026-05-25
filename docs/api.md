# API

This document describes the current MDAutomation backend API.

The API is implemented with FastAPI. Interactive documentation is exposed automatically by the running application:

- Swagger UI: `/docs`
- ReDoc: `/redoc`
- OpenAPI schema: `/openapi.json`

## Health

### `GET /health`

Checks that the backend application is running and can connect to the database.

Successful response status:

```text
200 OK
```

Successful response body:

```json
{
  "status": "ok",
  "database": "connected"
}
```

If the database is unavailable, the endpoint returns:

```text
503 Service Unavailable
```

Response body:

```json
{
  "status": "degraded",
  "database": "unavailable"
}
```

Example request:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
```
