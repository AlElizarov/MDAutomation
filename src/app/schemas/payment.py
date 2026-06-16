from enum import StrEnum

from pydantic import BaseModel


class PaymentWebhookEvent(StrEnum):
    succeeded = "payment.succeeded"
    failed = "payment.failed"


class PaymentWebhookRequest(BaseModel):
    event: PaymentWebhookEvent
    provider_payment_id: str


class PaymentWebhookResponse(BaseModel):
    status: str
