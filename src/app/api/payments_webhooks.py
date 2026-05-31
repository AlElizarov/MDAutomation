from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.schemas.payment import PaymentWebhookEvent, PaymentWebhookRequest, PaymentWebhookResponse
from app.services.payment_service import (
    PaymentNotFoundError,
    PaymentStatusUpdateError,
    mark_payment_failed,
    mark_payment_paid,
)


router = APIRouter(tags=["payment webhooks"])


@router.post(
    "/payments/webhooks/test-payment-provider",
    response_model=PaymentWebhookResponse,
    status_code=status.HTTP_200_OK,
)
def process_test_payment_webhook(
    webhook: PaymentWebhookRequest,
    db: Annotated[Session, Depends(get_db)],
) -> PaymentWebhookResponse:
    raw_payload = webhook.model_dump(mode="json")

    try:
        if webhook.event == PaymentWebhookEvent.succeeded:
            mark_payment_paid(
                db,
                provider="test",
                provider_payment_id=webhook.provider_payment_id,
                raw_payload=raw_payload,
            )
        elif webhook.event == PaymentWebhookEvent.failed:
            mark_payment_failed(
                db,
                provider="test",
                provider_payment_id=webhook.provider_payment_id,
                raw_payload=raw_payload,
            )
    except PaymentNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Payment was not found.",
        ) from exc
    except PaymentStatusUpdateError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to process payment webhook.",
        ) from exc

    return PaymentWebhookResponse(status="ok")
