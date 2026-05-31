# MDA-10 - Implement Payment model and payment status lifecycle

## Goal

Introduce a persistent Payment domain model and payment lifecycle management for Leads.

The backend must support:

- Lead creation together with Payment initialization;
- payment provider adapter abstraction;
- payment status tracking;
- transactional state updates;
- payment webhook processing;
- Lead status transitions based on payment state;
- preparation for future Telegram/VK/MAX onboarding flows.

This task establishes the payment foundation between:

```text
Lead creation
```

and:

```text
messenger contact binding
```

---

## Business Context

Target user flow:

```text
1. User fills the consultation form.
2. User presses "Pay".
3. Frontend calls POST /leads.
4. Backend creates:
   - Lead
   - local Payment
5. Backend calls payment provider adapter.
6. Provider adapter returns:
   - provider_payment_id
   - payment_url
7. Backend stores provider payment data.
8. Backend returns payment_url.
9. User completes payment through provider.
10. Payment provider sends webhook event.
11. Backend marks Payment as paid.
12. Lead becomes eligible for Telegram/VK/MAX binding.
```

The system must separate:

```text
Lead exists
```

from:

```text
Lead has successfully paid
```

---

## Scope

This task includes:

- Payment SQLAlchemy model;
- Payment persistence;
- payment lifecycle statuses;
- Lead to Payment relationship;
- extending `POST /leads`;
- payment provider adapter abstraction;
- test payment provider adapter;
- payment webhook endpoint;
- transactional payment state updates;
- Lead status updates;
- Alembic migration;
- service layer implementation;
- integration tests;
- documentation updates.

---

## Out of Scope

This task does not include:

- real payment provider integrations;
- payment signature verification;
- refunds;
- recurring payments;
- Telegram/VK/MAX deep-link flows;
- LeadContactBinding implementation;
- authentication;
- payment security hardening.

These are implemented in later MDA tasks.

---

## Functional Requirements

### Lead Creation Endpoint

#### Endpoint

```text
POST /leads
```

Creates:

- Lead;
- local Payment;
- provider-side payment through a provider adapter.

#### Request Payload

Example:

```json
{
  "name": "Anna Ivanova",
  "phone": "+79990000000",
  "preferred_contact_channel": "telegram",
  "amount": 99000,
  "currency": "RUB"
}
```

#### Validation Rules

Existing Lead validation rules remain unchanged.

`amount`:

- required;
- integer;
- must be greater than zero;
- stored in minimal currency units.

Example:

```text
99000 = 990.00 RUB
```

`currency`:

- required;
- uppercase string;
- ISO-style currency code;
- max length: 8.

Examples:

```text
RUB
USD
EUR
```

#### Processing Flow

`POST /leads` must:

```text
1. Create Lead.
2. Create local Payment with status = created.
3. Call PaymentProviderAdapter.create_payment(...).
4. Receive from provider:
   - provider_payment_id
   - payment_url
5. Update local Payment:
   - provider_payment_id
   - payment_url
   - status = pending
6. Set Lead.status = payment_pending.
7. Return:
   - lead_id
   - payment_url
```

`payment_url` must come from the provider adapter response. It must not be
generated directly in the API route or directly from the internal `Payment.id`.

#### Success Response

HTTP 201 Created

```json
{
  "lead_id": "<uuid>",
  "payment_url": "https://test-payment-provider/pay/<provider_payment_id>"
}
```

#### Error Responses

Validation error:

```text
422 Unprocessable Entity
```

Persistence or provider initialization error:

```text
500 Internal Server Error
```

---

### Payment Webhook Endpoint

#### Endpoint

```text
POST /payments/webhooks/test-payment-provider
```

Simulates future external payment provider webhooks.

The endpoint acts as a transport adapter only. Business logic must remain in the
service layer.

#### Webhook Payloads

Successful payment:

```json
{
  "event": "payment.succeeded",
  "provider_payment_id": "<provider_payment_id>"
}
```

Failed payment:

```json
{
  "event": "payment.failed",
  "provider_payment_id": "<provider_payment_id>"
}
```

The webhook payload must use `provider_payment_id`, not internal `Payment.id`.
External providers must not depend on internal database identifiers.

#### Webhook Response

Successful processing returns HTTP 200 OK:

```json
{
  "status": "ok"
}
```

#### Webhook Processing Rules

Successful payment must:

```text
- find Payment by provider and provider_payment_id
- set Payment.status = paid
- set Payment.paid_at
- set Lead.status = paid
- store webhook payload in Payment.raw_payload
```

Failed payment must:

```text
- find Payment by provider and provider_payment_id
- set Payment.status = failed
- keep Lead.status = payment_pending
- keep Payment.paid_at null
- store webhook payload in Payment.raw_payload
```

The Lead remains payable after failed payment attempts.

Webhook errors:

- unknown event returns `422 Unprocessable Entity`;
- invalid payload returns `422 Unprocessable Entity`;
- unknown `provider_payment_id` returns `404 Not Found`;
- persistence error returns `500 Internal Server Error`.

Webhook idempotency and strict invalid payment status transition rules are
intentionally deferred. This task only implements normalized test provider
events. Real provider integrations must define retry handling, provider event
identity, terminal status behavior, and invalid transition responses.

---

## Payment Provider Adapter Requirements

Add a payment provider adapter abstraction.

Suggested location:

```text
src/app/payments/providers/
|-- base.py
`-- test_provider.py
```

Minimum adapter responsibility:

```text
PaymentProviderAdapter.create_payment(...)
```

The adapter must return:

```text
provider_payment_id
payment_url
```

For the test provider:

```text
provider_payment_id != payment.id
payment_url = https://test-payment-provider/pay/{provider_payment_id}
```

Example:

```text
payment.id = 2e7d4f8e-1c85-4df0-9f15-9c7e0d2d2b61
provider_payment_id = test_pay_2e7d4f8e1c854df09f159c7e0d2d2b61
payment_url = https://test-payment-provider/pay/test_pay_2e7d4f8e1c854df09f159c7e0d2d2b61
```

The adapter abstraction is required even though this task only implements a test
provider. Future real providers must be integrated through the same boundary.

Provider selection may be hardcoded to the test provider in this task. A future
provider factory or configuration-driven provider resolver should be introduced
when real providers are added.

---

## Persistence Requirements

### Payment Model

Add ORM model:

```text
src/app/db/models/payment.py
```

Minimum fields:

```text
id
lead_id
provider
provider_payment_id
amount
currency
status
payment_url
created_at
updated_at
paid_at
raw_payload
```

### Field Details

`id`:

- UUID/string primary key;
- internal database identifier;
- must not be exposed to payment providers as their payment identifier.

`lead_id`:

- foreign key to `leads.id`.

`provider`:

- payment provider identifier.

Initial allowed values:

```text
test
manual
```

`provider_payment_id`:

- external provider payment identifier;
- must be distinct from internal `Payment.id`, including for the test provider;
- used for webhook lookup together with `provider`.

`amount`:

- payment amount in minimal currency units.

`currency`:

- currency code.

`status`:

- payment lifecycle status.

`payment_url`:

- redirect URL returned by the provider adapter and then returned to frontend.

`paid_at`:

- timestamp of successful payment confirmation;
- must remain null until payment becomes `paid`.

`raw_payload`:

- optional JSON payload storing webhook payloads.

---

## Payment Lifecycle

Supported statuses:

```text
created
pending
paid
failed
cancelled
refunded
```

Minimum required implementation:

```text
created
pending
paid
failed
```

Required transitions:

```text
Local Payment created
-> Payment.status = created

Provider payment initialized
-> Payment.status = pending

Webhook: payment.succeeded
-> Payment.status = paid

Webhook: payment.failed
-> Payment.status = failed
```

---

## Lead Lifecycle Updates

Current Lead status:

```text
created
```

must be extended to support payment lifecycle stages.

Minimum required statuses:

```text
created
payment_pending
paid
```

Required transitions:

```text
Lead created
-> Payment provider initialized
-> Lead.status = payment_pending

Webhook: payment.succeeded
-> Lead.status = paid

Webhook: payment.failed
-> Lead.status remains payment_pending
```

---

## Transaction Requirements

Lead creation, local Payment creation, provider payment initialization, local
Payment update, and Lead status update must be coordinated as one application
flow.

The backend must never produce states such as:

```text
Lead exists
but Payment creation failed
```

or:

```text
Payment exists
but provider_payment_id/payment_url was not stored
```

or:

```text
Payment exists
but Lead status was not updated
```

Webhook processing must also be transactional.

---

## Database Requirements

Add table:

```text
payments
```

Relationship:

```text
payments.lead_id -> leads.id
```

Alembic migrations must manage all schema changes.

Manual schema modification is prohibited.

---

## Suggested Repository Changes

```text
src/app/
|-- api/
|   |-- leads.py
|   `-- payments_webhooks.py
|
|-- db/
|   `-- models/
|       `-- payment.py
|
|-- payments/
|   `-- providers/
|       |-- base.py
|       `-- test_provider.py
|
|-- schemas/
|   `-- payment.py
|
`-- services/
    `-- payment_service.py

alembic/
`-- versions/
    `-- <timestamp>_create_payments_table.py

tests/
`-- test_payments.py
```

---

## Service Layer Requirements

Add:

```text
payment_service.py
```

Minimum responsibilities:

```text
create_payment(...)
mark_payment_paid(...)
mark_payment_failed(...)
```

Business logic must remain inside services rather than API route handlers.

`create_payment(...)` must call `PaymentProviderAdapter.create_payment(...)`
before returning the response data needed by `POST /leads`.

This follows the current project architecture rules.

---

## Testing Requirements

Add integration tests for:

- successful Lead + Payment creation;
- `POST /leads` response containing only `lead_id` and `payment_url`;
- invalid payload rejection;
- provider adapter invocation;
- `provider_payment_id` being distinct from internal `Payment.id`;
- transactional consistency;
- successful webhook processing by `provider_payment_id`;
- failed webhook processing by `provider_payment_id`;
- Lead status transitions;
- Payment status transitions;
- `paid_at` population;
- webhook payload storage in `raw_payload`;
- migration reproducibility.

All tests must pass through:

```powershell
.\scripts\dev\test.ps1
```

and:

```powershell
.\scripts\ci\local-ci.ps1
```

---

## Acceptance Criteria

MDA-10 is complete when:

- Payment ORM model exists;
- payments table migration exists;
- Payment is linked to Lead;
- payment provider adapter abstraction exists;
- test payment provider adapter exists;
- `POST /leads` creates Lead and Payment;
- `POST /leads` calls provider adapter before returning;
- `POST /leads` returns `lead_id` and `payment_url`;
- payment webhook endpoint is implemented;
- webhooks use `provider_payment_id`, not internal `Payment.id`;
- payment lifecycle statuses are implemented;
- Lead statuses update correctly;
- transactional guarantees are enforced;
- integration tests pass;
- Alembic migrations apply successfully;
- Docker environment works correctly;
- documentation is updated.

---

## Deliverables

- Payment ORM model;
- Payment service layer;
- payment provider adapter abstraction;
- test payment provider adapter;
- extended `POST /leads`;
- payment webhook endpoint;
- Alembic migration;
- integration tests;
- updated database documentation;
- updated architecture documentation;
- task documentation.

---

## Notes

This task introduces the payment domain layer required for future:

- payment provider integrations;
- paid consultation workflows;
- Telegram/VK/MAX onboarding;
- secure deep-link binding flows;
- CRM synchronization;
- operator dashboards.
