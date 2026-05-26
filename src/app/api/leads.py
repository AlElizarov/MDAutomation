from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.schemas.lead import LeadCreate, LeadCreateResponse
from app.services.lead_service import LeadCreationError, create_lead


router = APIRouter(tags=["leads"])


@router.post("/leads", response_model=LeadCreateResponse, status_code=status.HTTP_201_CREATED)
def create_lead_endpoint(
    lead_create: LeadCreate,
    db: Annotated[Session, Depends(get_db)],
) -> LeadCreateResponse:
    try:
        lead = create_lead(db, lead_create)
    except LeadCreationError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create lead.",
        ) from exc

    return LeadCreateResponse(lead_id=lead.id, status=lead.status)
