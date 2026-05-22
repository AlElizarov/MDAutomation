from fastapi.testclient import TestClient

from mda_automation import database
from mda_automation import main


client = TestClient(main.app)


def test_health_returns_ok_when_database_connected(monkeypatch) -> None:
    monkeypatch.setattr(main, "check_database_connection", lambda: True)

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "database": "connected"}


def test_health_returns_degraded_when_database_unavailable(monkeypatch) -> None:
    monkeypatch.setattr(main, "check_database_connection", lambda: False)

    response = client.get("/health")

    assert response.status_code == 503
    assert response.json() == {"status": "degraded", "database": "unavailable"}


def test_get_db_yields_session_and_closes_it(monkeypatch) -> None:
    class FakeSession:
        def __init__(self) -> None:
            self.closed = False

        def close(self) -> None:
            self.closed = True

    session = FakeSession()
    monkeypatch.setattr(database, "get_session_local", lambda: lambda: session)

    dependency = database.get_db()
    yielded_session = next(dependency)

    assert yielded_session is session
    assert session.closed is False

    try:
        next(dependency)
    except StopIteration:
        pass

    assert session.closed is True


def test_docs_available() -> None:
    response = client.get("/docs")

    assert response.status_code == 200


def test_openapi_json_available() -> None:
    response = client.get("/openapi.json")

    assert response.status_code == 200


def test_openapi_schema_generated_correctly() -> None:
    response = client.get("/openapi.json")
    schema = response.json()

    assert schema["openapi"].startswith("3.")
    assert schema["info"]["title"] == "MDAutomation API"
    assert "/health" in schema["paths"]
    assert "get" in schema["paths"]["/health"]
