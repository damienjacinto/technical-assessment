import os

from flask import Flask

app = Flask(__name__)

INDEX_HTML = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>the-redemption</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    background: radial-gradient(120% 140% at 50% 20%, #14161c 0%, #0d0e12 100%);
    color: #e9e4d8;
    font-family: Georgia, "Times New Roman", serif;
    padding: 2rem;
  }
  main {
    text-align: center;
    padding: 3.5rem 4.5rem;
    border: 1px solid #35311f;
    border-radius: 2px;
    max-width: 26rem;
  }
  .mark {
    font-size: 0.7rem;
    letter-spacing: 0.4em;
    text-transform: uppercase;
    color: #c9a457;
    margin: 0 0 1.5rem;
  }
  h1 {
    font-weight: 400;
    font-size: 2.1rem;
    letter-spacing: 0.04em;
    text-wrap: balance;
    margin: 0 0 0.75rem;
  }
  p {
    color: #9a9484;
    font-style: italic;
    font-size: 1rem;
    margin: 0;
  }
  .version {
    margin-top: 2.5rem;
    padding-top: 1.25rem;
    border-top: 1px solid #35311f;
    font-family: ui-monospace, "SF Mono", Consolas, monospace;
    font-size: 0.7rem;
    letter-spacing: 0.05em;
    color: #514c3d;
  }
</style>
</head>
<body>
  <main>
    <p class="mark">&#10022;</p>
    <h1>The Redemption</h1>
    <p>Every stay, remembered. Every point, redeemed.</p>
    <div class="version">v__VERSION__</div>
  </main>
</body>
</html>
"""


@app.get("/healthz")
def healthz():
    return "ok", 200


@app.get("/version")
def version():
    return os.environ.get("VERSION", "unset"), 200


@app.get("/")
def index():
    return INDEX_HTML.replace("__VERSION__", os.environ.get("VERSION", "unset")), 200
