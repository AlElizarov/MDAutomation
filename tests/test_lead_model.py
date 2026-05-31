from app.db.base import Base
from app.db.models import Payment  # noqa: F401
from app.db.models.lead import Lead
from sqlalchemy import create_engine
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session


def test_lead_model_is_registered_in_metadata() -> None:
    assert Lead.__tablename__ == "leads"
    assert Base.metadata.tables["leads"] is Lead.__table__


def test_lead_model_has_expected_columns() -> None:
    assert set(Lead.__table__.columns.keys()) == {
        "id",
        "name",
        "phone",
        "preferred_contact_channel",
        "status",
        "created_at",
        "updated_at",
    }


def test_lead_model_persists_valid_record() -> None:
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)

    with Session(engine) as session:
        lead = Lead(
            name="Alice",
            phone="+10000000000",
            preferred_contact_channel="telegram",
        )

        session.add(lead)
        session.commit()
        session.refresh(lead)

        assert lead.id
        assert lead.status == "created"
        assert lead.created_at is not None
        assert lead.updated_at is not None


def test_lead_model_rejects_missing_required_name() -> None:
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)

    with Session(engine) as session:
        lead = Lead(
            name=None,
            phone="+10000000000",
            preferred_contact_channel="telegram",
        )

        session.add(lead)

        try:
            session.commit()
        except IntegrityError:
            session.rollback()
        else:
            raise AssertionError("Expected missing lead name to violate the database schema.")
