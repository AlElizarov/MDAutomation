# MDA-9 - Implement Lead Creation API Flow

## Goal

Implement the initial Lead creation flow in the backend API.

The system must be able to:

- accept a consultation request from external clients;
- validate request payloads;
- persist Lead entities in PostgreSQL;
- return a stable API response;
- prepare the foundation for future channel bindings.

## Scope

This task includes:

- Lead database persistence;
- Lead SQLAlchemy model;
- Pydantic request/response schemas;
- `POST /leads` endpoint;
- input validation;
- integration tests;
- API error handling.

This task does not include:

- messenger bindings;
- Telegram/VK/MAX integrations;
- authentication;
- rate limiting;
- CRM synchronization;
- onboarding flow logic.

## Functional Requirements

### Endpoint

```text
POST /leads
```

### Request Payload

```json
{
  "name": "Anna Ivanova",
  "phone": "+79990000000",
  "preferred_contact_channel": "telegram"
}
```

### Validation Rules

#### `name`

- required;
- string;
- non-empty;
- max length: 255.

#### `phone`

- required;
- string;
- normalized format;
- max length: 32.

#### `preferred_contact_channel`

Allowed values:

- `telegram`;
- `vk`;
- `max`.

## Persistence Requirements

### Lead Model

The Lead entity must contain at minimum:

```text
id
created_at
updated_at
name
phone
preferred_contact_channel
status
```

### Initial Status

Newly created Leads must receive:

```text
created
```

## API Response

### Success Response

HTTP 201 Created

```json
{
  "lead_id": "<uuid>",
  "status": "created"
}
```

### Error Responses

Validation error:

```text
422 Unprocessable Entity
```

Internal server error:

```text
500 Internal Server Error
```

## Technical Requirements

### Framework

- FastAPI;
- SQLAlchemy;
- PostgreSQL;
- Alembic;
- Pydantic.

### Database

The endpoint must persist data into PostgreSQL.

SQLite must not be used.

### Database Separation

Local development and smoke testing must use separate PostgreSQL databases on
the same persistent Docker volume:

- `mda_dev` is used by the local backend server.
- `mda_test` is used by Docker smoke tests.

Smoke tests must not write into `mda_dev`.

The Docker smoke test must:

1. start PostgreSQL with the persistent Docker volume;
2. recreate the `mda_test` database;
3. start the backend against `mda_test`;
4. create a Lead through `POST /leads`;
5. verify that the Lead is persisted;
6. restart the PostgreSQL container;
7. verify that the Lead still exists;
8. clean up by dropping only `mda_test`.

The smoke test must not delete the Docker volume.

### Transaction Handling

Lead creation must be transactional.

Partial writes are not allowed.

### UUID

Lead identifiers must use UUID.

## Testing Requirements

### Integration Tests

Add integration tests for:

- successful Lead creation;
- invalid payload rejection;
- invalid channel rejection;
- persistence verification;
- response schema validation.

### Health Requirements

All tests must pass through:

```powershell
.\scripts\dev\test.ps1
```

and:

```powershell
.\scripts\ci\local-ci.ps1
```

## Acceptance Criteria

MDA-9 is complete when:

- `POST /leads` is implemented;
- Lead entities are persisted in PostgreSQL;
- validation rules are enforced;
- integration tests pass;
- Alembic migration exists;
- Docker environment works correctly;
- CI passes successfully.

## Suggested Repository Changes

Use the current repository structure rather than the generic task layout.

Expected areas:

```text
src/app/
|-- api/
|   `-- leads.py
|-- db/
|   `-- models/
|       `-- lead.py
|-- schemas/
|   `-- lead.py
`-- services/
    `-- lead_service.py

tests/
`-- test_app.py
```

## Notes

This task establishes the foundational domain entity of the platform.

Future channel integrations must operate through Lead entities rather than
creating channel-specific request flows.
