import os
import socket
from flask import Flask, jsonify

app = Flask(__name__)

VERSION = os.environ.get("APP_VERSION", "1.0")


@app.route("/api/hello")
def hello():
    return jsonify({
        "message": "Hello from Kubernetes backend",
        "pod": socket.gethostname(),
        "version": VERSION
    })


@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
