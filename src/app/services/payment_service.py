from datetime import UTC, datetime
from typing import Any

from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.db.models.payment import Payment
from app.payments.providers.base import PaymentProviderAdapter


class PaymentCreationError(RuntimeError):
    pass


class PaymentNotFoundError(RuntimeError):
    pass


class PaymentStatusUpdateError(RuntimeError):
    pass


def create_payment(
    db: Session,
    *,
    lead_id: str,
    amount: int,
    currency: str,
    provider_adapter: PaymentProviderAdapter,
) -> Payment:
    payment = Payment(
        lead_id=lead_id,
        provider=provider_adapter.provider,
        amount=amount,
        currency=currency,
        status="created",
    )

    try:
        db.add(payment)
        db.flush()

        provider_payment = provider_adapter.create_payment(
            payment_id=payment.id,
            amount=payment.amount,
            currency=payment.currency,
        )

        if not provider_payment.provider_payment_id or not provider_payment.payment_url:
            raise PaymentCreationError("Provider payment response was incomplete.")

        payment.provider_payment_id = provider_payment.provider_payment_id
        payment.payment_url = provider_payment.payment_url
        payment.status = "pending"
        db.flush()
    except SQLAlchemyError as exc:
        raise PaymentCreationError("Failed to create payment.") from exc
    except PaymentCreationError:
        raise
    except Exception as exc:
        raise PaymentCreationError("Failed to initialize provider payment.") from exc

    return payment


def mark_payment_paid(
    db: Session,
    *,
    provider: str,
    provider_payment_id: str,
    raw_payload: dict[str, Any],
) -> Payment:
    payment = _get_payment_by_provider_id(
        db,
        provider=provider,
        provider_payment_id=provider_payment_id,
    )

    try:
        payment.status = "paid"
        payment.paid_at = datetime.now(UTC)
        payment.raw_payload = raw_payload
        payment.lead.status = "paid"
        db.commit()
        db.refresh(payment)
    except SQLAlchemyError as exc:
        db.rollback()
        raise PaymentStatusUpdateError("Failed to mark payment paid.") from exc

    return payment


def mark_payment_failed(
    db: Session,
    *,
    provider: str,
    provider_payment_id: str,
    raw_payload: dict[str, Any],
) -> Payment:
    payment = _get_payment_by_provider_id(
        db,
        provider=provider,
        provider_payment_id=provider_payment_id,
    )

    try:
        payment.status = "failed"
        payment.raw_payload = raw_payload
        db.commit()
        db.refresh(payment)
    except SQLAlchemyError as exc:
        db.rollback()
        raise PaymentStatusUpdateError("Failed to mark payment failed.") from exc

    return payment


def _get_payment_by_provider_id(
    db: Session,
    *,
    provider: str,
    provider_payment_id: str,
) -> Payment:
    payment = (
        db.query(Payment)
        .filter(
            Payment.provider == provider,
            Payment.provider_payment_id == provider_payment_id,
        )
        .one_or_none()
    )

    if payment is None:
        raise PaymentNotFoundError("Payment was not found.")

    return payment
