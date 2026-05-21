# API

This document describes the current MDAutomation backend API.

The API is implemented with FastAPI. Interactive documentation is exposed automatically by the running application:

- Swagger UI: `/docs`
- ReDoc: `/redoc`
- OpenAPI schema: `/openapi.json`

## Health

### `GET /health`

Checks that the backend application is running and can accept HTTP requests.

Response status:

```text
200 OK
```

Response body:

```json
{
  "status": "ok"
}
```

Example request:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
```
