# Berserk Helm Charts

Helm charts for deploying [Berserk](https://github.com/berserkdb) - a high-performance observability data platform.

## Usage

```bash
helm repo add berserk https://berserkdb.github.io/helm-charts
helm repo update
```

### Install

```bash
helm install berserk berserk/berserk \
  --namespace bzrk \
  --create-namespace \
  --version 1.0.0 \
  -f values.yaml
```

### Release new version
When releasing a new version run:

```bash
scripts/set-version.sh
```

### Prerequisites

Before installing, create the required Kubernetes secrets:

```bash
# GHCR pull credentials (provided by Berserk team)
kubectl create secret docker-registry ghcr-credentials \
  --namespace bzrk \
  --docker-server=ghcr.io \
  --docker-username=<username> \
  --docker-password=<token>

# S3 storage credentials
kubectl create secret generic s3-credentials \
  --namespace bzrk \
  --from-literal=AWS_ACCESS_KEY_ID=<key> \
  --from-literal=AWS_SECRET_ACCESS_KEY=<secret>

# PostgreSQL credentials
kubectl create secret generic postgres-credentials \
  --namespace bzrk \
  --from-literal=database_url=<postgres-url>
```

### Minimal values.yaml

```yaml
global:
  imageTag: "v1.0.0"
  storage:
    endpoint: "https://s3.example.com"
    bucket: "berserk-data"
    region: "us-east-1"
```

### Template Debugging

```bash
helm template berserk berserk/berserk -f values.yaml
```

## Services

| Service | Description | Default Port |
|---------|-------------|-------------|
| meta | Metadata management | 9500 |
| query | Query engine | 9510 |
| ingest | Telemetry ingestion (OTLP) | 4317/4318 |
| janitor | Background maintenance | - |
| nursery | Baby segment management | 3002 |
| ui | Web interface | 80 |
