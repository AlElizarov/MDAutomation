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

## Leads

### `POST /leads`

Creates a new consultation Lead.

Request body:

```json
{
  "name": "Anna Ivanova",
  "phone": "+79990000000",
  "preferred_contact_channel": "telegram"
}
```

Validation rules:

- `name` is required, trimmed, non-empty, and limited to 255 characters.
- `phone` is required, trimmed, starts with `+`, contains only digits after `+`,
  and is limited to 32 characters.
- `preferred_contact_channel` must be one of `telegram`, `vk`, or `max`.

Successful response status:

```text
201 Created
```

Successful response body:

```json
{
  "lead_id": "<uuid>",
  "status": "created"
}
```

Validation errors return:

```text
422 Unprocessable Entity
```

Persistence errors return:

```text
500 Internal Server Error
```

Example request:

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri http://127.0.0.1:8000/leads `
  -ContentType "application/json" `
  -Body '{"name":"Anna Ivanova","phone":"+79990000000","preferred_contact_channel":"telegram"}'
```
