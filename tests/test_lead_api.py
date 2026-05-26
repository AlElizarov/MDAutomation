from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app import main
from app.api import leads as leads_api
from app.db import session as db_session
from app.db.base import Base
from app.db.models import Lead  # noqa: F401


client = TestClient(main.app)


def override_get_dummy_db():
    yield object()


def test_create_lead_returns_created_response_and_persists_record() -> None:
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

    main.app.dependency_overrides[db_session.get_db] = override_get_db

    try:
        response = client.post(
            "/leads",
            json={
                "name": " Anna Ivanova ",
                "phone": "+79990000000",
                "preferred_contact_channel": "telegram",
            },
        )

        assert response.status_code == 201
        response_body = response.json()
        assert set(response_body.keys()) == {"lead_id", "status"}
        assert response_body["lead_id"]
        assert response_body["status"] == "created"

        with engine.connect() as connection:
            persisted = connection.execute(
                text(
                    """
                    SELECT name, phone, preferred_contact_channel, status, created_at, updated_at
                    FROM leads
                    WHERE id = :lead_id
                    """
                ),
                {"lead_id": response_body["lead_id"]},
            ).mappings().one()

        assert persisted["name"] == "Anna Ivanova"
        assert persisted["phone"] == "+79990000000"
        assert persisted["preferred_contact_channel"] == "telegram"
        assert persisted["status"] == "created"
        assert persisted["created_at"] is not None
        assert persisted["updated_at"] is not None
    finally:
        main.app.dependency_overrides.clear()


def test_create_lead_rejects_empty_name() -> None:
    main.app.dependency_overrides[db_session.get_db] = override_get_dummy_db

    try:
        response = client.post(
            "/leads",
            json={
                "name": " ",
                "phone": "+79990000000",
                "preferred_contact_channel": "telegram",
            },
        )
    finally:
        main.app.dependency_overrides.clear()

    assert response.status_code == 422


def test_create_lead_rejects_invalid_phone() -> None:
    main.app.dependency_overrides[db_session.get_db] = override_get_dummy_db

    try:
        response = client.post(
            "/leads",
            json={
                "name": "Anna Ivanova",
                "phone": "79990000000",
                "preferred_contact_channel": "telegram",
            },
        )
    finally:
        main.app.dependency_overrides.clear()

    assert response.status_code == 422


def test_create_lead_rejects_invalid_channel() -> None:
    main.app.dependency_overrides[db_session.get_db] = override_get_dummy_db

    try:
        response = client.post(
            "/leads",
            json={
                "name": "Anna Ivanova",
                "phone": "+79990000000",
                "preferred_contact_channel": "email",
            },
        )
    finally:
        main.app.dependency_overrides.clear()

    assert response.status_code == 422


def test_create_lead_returns_internal_server_error_when_persistence_fails(monkeypatch) -> None:
    class FakeSession:
        pass

    def override_get_db():
        yield FakeSession()

    def fail_create_lead(db, lead_create):
        raise leads_api.LeadCreationError("boom")

    main.app.dependency_overrides[db_session.get_db] = override_get_db
    monkeypatch.setattr(leads_api, "create_lead", fail_create_lead)

    try:
        response = client.post(
            "/leads",
            json={
                "name": "Anna Ivanova",
                "phone": "+79990000000",
                "preferred_contact_channel": "telegram",
            },
        )

        assert response.status_code == 500
        assert response.json() == {"detail": "Failed to create lead."}
    finally:
        main.app.dependency_overrides.clear()
