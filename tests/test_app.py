from app import app


def test_index_returns_fields():
    resp = app.test_client().get("/")
    assert resp.status_code == 200
    data = resp.get_json()
    assert "version" in data
    assert "node" in data


def test_node_name_from_env(monkeypatch):
    monkeypatch.setenv("NODE_NAME", "node1")
    resp = app.test_client().get("/")
    assert resp.get_json()["node"] == "node1"


def test_version_from_env(monkeypatch):
    monkeypatch.setenv("APP_VERSION", "1.2.3")
    resp = app.test_client().get("/")
    assert resp.get_json()["version"] == "1.2.3"


def test_health_ok(monkeypatch):
    monkeypatch.delenv("FAIL_HEALTH", raising=False)
    resp = app.test_client().get("/health")
    assert resp.status_code == 200
    assert resp.get_json()["status"] == "broken"


def test_health_fails_when_flag_set(monkeypatch):
    monkeypatch.setenv("FAIL_HEALTH", "1")
    resp = app.test_client().get("/health")
    assert resp.status_code == 503
