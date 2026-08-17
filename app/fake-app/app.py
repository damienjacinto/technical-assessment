import os

from flask import Flask

app = Flask(__name__)


@app.get("/healthz")
def healthz():
    return "ok", 200


@app.get("/version")
def version():
    return os.environ.get("VERSION", "unset"), 200


@app.get("/")
def index():
    return "the-redemption placeholder", 200
