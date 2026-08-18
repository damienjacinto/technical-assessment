# Placeholder app for the-redemption: no business logic, just a Flask
# stub wrapped in OTel zero-code auto-instrumentation so it actually
# emits the metrics KEDA/Argo Rollouts query against (docs/ARCHITECTURE.md).
FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && opentelemetry-bootstrap -a install

COPY app.py .

ARG VERSION=unset
ENV VERSION=${VERSION}
ENV FLASK_APP=app.py
EXPOSE 8080
USER 65532:65532

ENTRYPOINT ["opentelemetry-instrument", "flask", "run", "--host=0.0.0.0", "--port=8080"]
