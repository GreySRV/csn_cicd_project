import os
import socket

from flask import Flask, jsonify

app = Flask(__name__)


def node_name():
    return os.environ.get("NODE_NAME") or socket.gethostname()


@app.route("/")
def index():
    return jsonify(
        message="Hello from CSN CI/CD project v2",
        version=os.environ.get("APP_VERSION", "dev"),
        node=node_name(),
    )


@app.route("/health")
def health():
    if os.environ.get("FAIL_HEALTH") == "1":
        return jsonify(status="unhealthy"), 503
    return jsonify(status="ok")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
