from app.db.base import Base
from app.db.models import Lead, Payment
from sqlalchemy import create_engine
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session


def test_payment_model_is_registered_in_metadata() -> None:
    assert Payment.__tablename__ == "payments"
    assert Base.metadata.tables["payments"] is Payment.__table__


def test_payment_model_has_expected_columns() -> None:
    assert set(Payment.__table__.columns.keys()) == {
        "id",
        "lead_id",
        "provider",
        "provider_payment_id",
        "amount",
        "currency",
        "status",
        "payment_url",
        "created_at",
        "updated_at",
        "paid_at",
        "raw_payload",
    }


def test_payment_model_persists_valid_record() -> None:
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)

    with Session(engine) as session:
        lead = create_lead(session)

        payment = Payment(
            lead_id=lead.id,
            provider="test",
            provider_payment_id="test_pay_external",
            amount=99000,
            currency="RUB",
            status="pending",
            payment_url="https://test-payment-provider/pay/test_pay_external",
        )

        session.add(payment)
        session.commit()
        session.refresh(payment)

        assert payment.id
        assert payment.provider_payment_id != payment.id
        assert payment.status == "pending"
        assert payment.created_at is not None
        assert payment.updated_at is not None


def test_payment_model_rejects_missing_lead_id() -> None:
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)

    with Session(engine) as session:
        payment = Payment(
            lead_id=None,
            provider="test",
            amount=99000,
            currency="RUB",
        )

        session.add(payment)

        try:
            session.commit()
        except IntegrityError:
            session.rollback()
        else:
            raise AssertionError("Expected missing payment lead_id to violate the database schema.")


def test_payment_model_rejects_missing_provider() -> None:
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)

    with Session(engine) as session:
        lead = create_lead(session)
        payment = Payment(
            lead_id=lead.id,
            provider=None,
            amount=99000,
            currency="RUB",
        )

        session.add(payment)

        try:
            session.commit()
        except IntegrityError:
            session.rollback()
        else:
            raise AssertionError("Expected missing payment provider to violate the database schema.")


def test_payment_model_rejects_missing_amount() -> None:
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)

    with Session(engine) as session:
        lead = create_lead(session)
        payment = Payment(
            lead_id=lead.id,
            provider="test",
            amount=None,
            currency="RUB",
        )

        session.add(payment)

        try:
            session.commit()
        except IntegrityError:
            session.rollback()
        else:
            raise AssertionError("Expected missing payment amount to violate the database schema.")


def test_payment_model_rejects_missing_currency() -> None:
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)

    with Session(engine) as session:
        lead = create_lead(session)
        payment = Payment(
            lead_id=lead.id,
            provider="test",
            amount=99000,
            currency=None,
        )

        session.add(payment)

        try:
            session.commit()
        except IntegrityError:
            session.rollback()
        else:
            raise AssertionError("Expected missing payment currency to violate the database schema.")


def create_lead(session: Session) -> Lead:
    lead = Lead(
        name="Alice",
        phone="+10000000000",
        preferred_contact_channel="telegram",
    )
    session.add(lead)
    session.flush()

    return lead
