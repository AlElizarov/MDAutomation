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

Creates a new consultation Lead, initializes a local Payment, calls the test
payment provider adapter, and returns the payment URL for the frontend.

Request body:

```json
{
  "name": "Anna Ivanova",
  "phone": "+79990000000",
  "preferred_contact_channel": "telegram",
  "amount": 99000,
  "currency": "RUB"
}
```

Validation rules:

- `name` is required, trimmed, non-empty, and limited to 255 characters.
- `phone` is required, trimmed, starts with `+`, contains only digits after `+`,
  and is limited to 32 characters.
- `preferred_contact_channel` must be one of `telegram`, `vk`, or `max`.
- `amount` is required, must be an integer greater than zero, and is stored in
  minimal currency units.
- `currency` is required, uppercase, ISO-style, alphabetic, and limited to 8
  characters.

Successful response status:

```text
201 Created
```

Successful response body:

```json
{
  "lead_id": "<uuid>",
  "payment_url": "https://test-payment-provider/pay/<provider_payment_id>"
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

On success, the created Lead receives `payment_pending` status. The local
Payment is stored with `pending` status after the test provider adapter returns
`provider_payment_id` and `payment_url`.

Example request:

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri http://127.0.0.1:8000/leads `
  -ContentType "application/json" `
  -Body '{"name":"Anna Ivanova","phone":"+79990000000","preferred_contact_channel":"telegram","amount":99000,"currency":"RUB"}'
```

## Payment Webhooks

### `POST /payments/webhooks/test-payment-provider`

Processes simulated payment events from the test payment provider.

The endpoint is a transport adapter. Payment lifecycle changes are handled by
the service layer.

Successful payment request body:

```json
{
  "event": "payment.succeeded",
  "provider_payment_id": "<provider_payment_id>"
}
```

Failed payment request body:

```json
{
  "event": "payment.failed",
  "provider_payment_id": "<provider_payment_id>"
}
```

Successful response status:

```text
200 OK
```

Successful response body:

```json
{
  "status": "ok"
}
```

Webhook behavior:

- `payment.succeeded` sets Payment status to `paid`, sets `paid_at`, stores the
  raw payload, and sets Lead status to `paid`.
- `payment.failed` sets Payment status to `failed`, stores the raw payload, and
  leaves Lead status as `payment_pending`.
- `provider_payment_id` is the external provider identifier. It is distinct
  from internal `Payment.id`.

Webhook errors:

- unknown event returns `422 Unprocessable Entity`;
- unknown `provider_payment_id` returns `404 Not Found`;
- persistence errors return `500 Internal Server Error`.

Example request:

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri http://127.0.0.1:8000/payments/webhooks/test-payment-provider `
  -ContentType "application/json" `
  -Body '{"event":"payment.succeeded","provider_payment_id":"test_pay_<id>"}'
```
