from fastapi.testclient import TestClient

from mda_automation.main import app


client = TestClient(app)


def test_health_returns_ok() -> None:
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


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
