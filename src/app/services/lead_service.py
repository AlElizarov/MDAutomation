from dataclasses import dataclass

from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.db.models.lead import Lead
from app.payments.providers.test_provider import TestPaymentProviderAdapter
from app.schemas.lead import LeadCreate
from app.services.payment_service import PaymentCreationError, create_payment


class LeadCreationError(RuntimeError):
    pass


@dataclass(frozen=True)
class LeadCreationResult:
    lead: Lead
    payment_url: str


def create_lead(db: Session, lead_create: LeadCreate) -> LeadCreationResult:
    lead = Lead(
        name=lead_create.name,
        phone=lead_create.phone,
        preferred_contact_channel=lead_create.preferred_contact_channel.value,
        status="created",
    )

    try:
        db.add(lead)
        db.flush()

        payment = create_payment(
            db,
            lead_id=lead.id,
            amount=lead_create.amount,
            currency=lead_create.currency,
            # TODO: Move provider selection behind a factory/config boundary when real providers are added.
            provider_adapter=TestPaymentProviderAdapter(),
        )

        lead.status = "payment_pending"
        db.commit()
        db.refresh(lead)
        db.refresh(payment)
    except (SQLAlchemyError, PaymentCreationError) as exc:
        db.rollback()
        raise LeadCreationError("Failed to create lead.") from exc

    return LeadCreationResult(lead=lead, payment_url=payment.payment_url)
