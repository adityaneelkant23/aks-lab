import os
from flask import Flask, jsonify

app = Flask(__name__)

APP_VERSION = os.environ.get("APP_VERSION", "v1")
POD_NAME    = os.environ.get("HOSTNAME", "unknown-pod")
NODE_NAME   = os.environ.get("NODE_NAME", "unknown-node")
NAMESPACE   = os.environ.get("POD_NAMESPACE", "default")


@app.route("/")
def index():
    return f"""
<!DOCTYPE html>
<html>
<head>
  <title>AKS Hello World</title>
  <style>
    body {{ font-family: Arial, sans-serif; background: #5c2d91; color: white; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }}
    .card {{ background: rgba(255,255,255,0.15); border-radius: 12px; padding: 40px 60px; text-align: center; box-shadow: 0 8px 32px rgba(0,0,0,0.3); }}
    h1 {{ font-size: 2.5rem; margin-bottom: 10px; }}
    .badge {{ background: rgba(255,255,255,0.25); border-radius: 6px; padding: 6px 14px; margin: 6px; display: inline-block; font-size: 0.95rem; }}
  </style>
</head>
<body>
  <div class="card">
    <h1>Hello from AKS!</h1>
    <p>Your private Azure Kubernetes Service is running.</p>
    <div>
      <span class="badge">Version: {APP_VERSION}</span>
      <span class="badge">Pod: {POD_NAME}</span>
      <span class="badge">Node: {NODE_NAME}</span>
      <span class="badge">Namespace: {NAMESPACE}</span>
    </div>
  </div>
</body>
</html>
"""


@app.route("/health")
def health():
    return jsonify({"status": "healthy", "version": APP_VERSION}), 200


@app.route("/info")
def info():
    return jsonify({
        "version":   APP_VERSION,
        "pod":       POD_NAME,
        "node":      NODE_NAME,
        "namespace": NAMESPACE,
    }), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
