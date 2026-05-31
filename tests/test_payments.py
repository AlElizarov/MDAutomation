from urllib.parse import urlparse

from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app import main
from app.db import session as db_session
from app.db.base import Base
from app.db.models import Lead, Payment  # noqa: F401
from app.payments.providers.base import ProviderPayment


client = TestClient(main.app)


def create_test_session():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    Base.metadata.create_all(engine)

    def override_get_db():
        db = TestingSessionLocal()

        try:
            yield db
        finally:
            db.close()

    return engine, override_get_db


def post_lead() -> dict:
    response = client.post(
        "/leads",
        json={
            "name": "Anna Ivanova",
            "phone": "+79990000000",
            "preferred_contact_channel": "telegram",
            "amount": 99000,
            "currency": "RUB",
        },
    )

    assert response.status_code == 201
    return response.json()


def test_create_lead_creates_payment_and_initializes_provider_payment() -> None:
    engine, override_get_db = create_test_session()
    main.app.dependency_overrides[db_session.get_db] = override_get_db

    try:
        response_body = post_lead()

        with engine.connect() as connection:
            payment = connection.execute(
                text(
                    """
                    SELECT p.id, p.lead_id, p.provider, p.provider_payment_id, p.amount,
                           p.currency, p.status, p.payment_url, l.status AS lead_status
                    FROM payments p
                    JOIN leads l ON l.id = p.lead_id
                    WHERE p.lead_id = :lead_id
                    """
                ),
                {"lead_id": response_body["lead_id"]},
            ).mappings().one()

        assert payment["provider"] == "test"
        assert payment["provider_payment_id"]
        assert payment["provider_payment_id"] != payment["id"]
        assert payment["amount"] == 99000
        assert payment["currency"] == "RUB"
        assert payment["status"] == "pending"
        assert payment["lead_status"] == "payment_pending"
        payment_url = response_body["payment_url"]
        parsed_payment_url = urlparse(payment_url)

        assert parsed_payment_url.scheme == "https"
        assert parsed_payment_url.netloc == "test-payment-provider"
        assert parsed_payment_url.path == f"/pay/{payment['provider_payment_id']}"
        assert response_body == {
            "lead_id": payment["lead_id"],
            "payment_url": payment["payment_url"],
        }
    finally:
        main.app.dependency_overrides.clear()


def test_create_lead_rejects_invalid_amount_and_currency() -> None:
    main.app.dependency_overrides[db_session.get_db] = lambda: iter([object()])

    try:
        response = client.post(
            "/leads",
            json={
                "name": "Anna Ivanova",
                "phone": "+79990000000",
                "preferred_contact_channel": "telegram",
                "amount": 0,
                "currency": "rub",
            },
        )
    finally:
        main.app.dependency_overrides.clear()

    assert response.status_code == 422


def test_create_lead_rolls_back_when_provider_initialization_fails(monkeypatch) -> None:
    class FailingProviderAdapter:
        provider = "test"

        def create_payment(self, *, payment_id: str, amount: int, currency: str) -> ProviderPayment:
            raise RuntimeError("provider unavailable")

    engine, override_get_db = create_test_session()
    main.app.dependency_overrides[db_session.get_db] = override_get_db
    monkeypatch.setattr("app.services.lead_service.TestPaymentProviderAdapter", FailingProviderAdapter)

    try:
        response = client.post(
            "/leads",
            json={
                "name": "Anna Ivanova",
                "phone": "+79990000000",
                "preferred_contact_channel": "telegram",
                "amount": 99000,
                "currency": "RUB",
            },
        )

        assert response.status_code == 500

        with engine.connect() as connection:
            lead_count = connection.execute(text("SELECT COUNT(*) FROM leads")).scalar_one()
            payment_count = connection.execute(text("SELECT COUNT(*) FROM payments")).scalar_one()

        assert lead_count == 0
        assert payment_count == 0
    finally:
        main.app.dependency_overrides.clear()


def test_successful_webhook_marks_payment_paid_and_updates_lead() -> None:
    engine, override_get_db = create_test_session()
    main.app.dependency_overrides[db_session.get_db] = override_get_db

    try:
        response_body = post_lead()

        with engine.connect() as connection:
            provider_payment_id = connection.execute(
                text("SELECT provider_payment_id FROM payments WHERE lead_id = :lead_id"),
                {"lead_id": response_body["lead_id"]},
            ).scalar_one()

        response = client.post(
            "/payments/webhooks/test-payment-provider",
            json={
                "event": "payment.succeeded",
                "provider_payment_id": provider_payment_id,
            },
        )

        assert response.status_code == 200
        assert response.json() == {"status": "ok"}

        with engine.connect() as connection:
            persisted = connection.execute(
                text(
                    """
                    SELECT p.status, p.paid_at, p.raw_payload, l.status AS lead_status
                    FROM payments p
                    JOIN leads l ON l.id = p.lead_id
                    WHERE p.provider_payment_id = :provider_payment_id
                    """
                ),
                {"provider_payment_id": provider_payment_id},
            ).mappings().one()

        assert persisted["status"] == "paid"
        assert persisted["paid_at"] is not None
        assert "payment.succeeded" in persisted["raw_payload"]
        assert persisted["lead_status"] == "paid"
    finally:
        main.app.dependency_overrides.clear()


def test_failed_webhook_marks_payment_failed_and_keeps_lead_payment_pending() -> None:
    engine, override_get_db = create_test_session()
    main.app.dependency_overrides[db_session.get_db] = override_get_db

    try:
        response_body = post_lead()

        with engine.connect() as connection:
            provider_payment_id = connection.execute(
                text("SELECT provider_payment_id FROM payments WHERE lead_id = :lead_id"),
                {"lead_id": response_body["lead_id"]},
            ).scalar_one()

        response = client.post(
            "/payments/webhooks/test-payment-provider",
            json={
                "event": "payment.failed",
                "provider_payment_id": provider_payment_id,
            },
        )

        assert response.status_code == 200

        with engine.connect() as connection:
            persisted = connection.execute(
                text(
                    """
                    SELECT p.status, p.paid_at, p.raw_payload, l.status AS lead_status
                    FROM payments p
                    JOIN leads l ON l.id = p.lead_id
                    WHERE p.provider_payment_id = :provider_payment_id
                    """
                ),
                {"provider_payment_id": provider_payment_id},
            ).mappings().one()

        assert persisted["status"] == "failed"
        assert persisted["paid_at"] is None
        assert "payment.failed" in persisted["raw_payload"]
        assert persisted["lead_status"] == "payment_pending"
    finally:
        main.app.dependency_overrides.clear()


def test_webhook_returns_not_found_for_unknown_provider_payment_id() -> None:
    _, override_get_db = create_test_session()
    main.app.dependency_overrides[db_session.get_db] = override_get_db

    try:
        response = client.post(
            "/payments/webhooks/test-payment-provider",
            json={
                "event": "payment.succeeded",
                "provider_payment_id": "missing",
            },
        )
    finally:
        main.app.dependency_overrides.clear()

    assert response.status_code == 404


def test_webhook_rejects_unknown_event() -> None:
    main.app.dependency_overrides[db_session.get_db] = lambda: iter([object()])

    try:
        response = client.post(
            "/payments/webhooks/test-payment-provider",
            json={
                "event": "payment.unknown",
                "provider_payment_id": "test_pay_missing",
            },
        )
    finally:
        main.app.dependency_overrides.clear()

    assert response.status_code == 422
