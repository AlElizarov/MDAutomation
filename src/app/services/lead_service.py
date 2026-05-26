from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.db.models.lead import Lead
from app.schemas.lead import LeadCreate


class LeadCreationError(RuntimeError):
    pass


def create_lead(db: Session, lead_create: LeadCreate) -> Lead:
    lead = Lead(
        name=lead_create.name,
        phone=lead_create.phone,
        preferred_contact_channel=lead_create.preferred_contact_channel.value,
        status="created",
    )

    try:
        db.add(lead)
        db.commit()
        db.refresh(lead)
    except SQLAlchemyError as exc:
        db.rollback()
        raise LeadCreationError("Failed to create lead.") from exc

    return lead
