# Berserk Helm Charts

Helm charts for deploying [Berserk](https://github.com/berserkdb) - a high-performance observability data platform.

In order to run Berserk, it requires a Postgres (at least version 18) and an S3-compatible blob storage.

## Prerequisites

Before installing, create the namespace and required Kubernetes secrets:

```bash
kubectl create namespace bzrk
```

### 1. GHCR Pull Credentials

Berserk images are hosted on GitHub Container Registry. Contact the Berserk team for access credentials.

```bash
kubectl create secret docker-registry ghcr-credentials \
  --namespace bzrk \
  --docker-server=ghcr.io \
  --docker-username=<username> \
  --docker-password=<token>
```

### 2. S3 Storage Credentials

Berserk stores data in S3-compatible object storage. Create a secret with your access keys:

```bash
kubectl create secret generic s3-credentials \
  --namespace bzrk \
  --from-literal=AWS_ACCESS_KEY_ID=<key> \
  --from-literal=AWS_SECRET_ACCESS_KEY=<secret>
```

### 3. PostgreSQL Credentials

Berserk uses PostgreSQL for metadata storage. Provide a connection URL:

```bash
kubectl create secret generic postgres-credentials \
  --namespace bzrk \
  --from-literal=database_url="postgres://user:password@host:5432/berserk"
```

## Installation

### Add the Helm Repository

```bash
helm repo add berserk https://berserkdb.github.io/helm-charts
helm repo update
```

### Install the Chart

```bash
helm install berserk berserk/berserk \
  --namespace bzrk \
  -f values.yaml
```

### Create an ingest token

If you need to create an ingest token, you can run the following command:

```bash
  kubectl run bzrk-cli --rm -it -n bzrk --image=ghcr.io/berserkdb/cli:latest -- \
    --endpoint meta:9500 ingest-token create --dataset default my-ingest-token
```

Use it in your otel-collectors export

Alternatively, you can set it as a default ingest token in the ingester service by
creating a Kubernetes secret via:

```bash
kubectl create secret generic ingest-token \
  --namespace=bzrk\
  --from-literal=default_ingest_token="your-token-value-here"
```

### Example Values

See the [examples/](examples/) directory for ready-to-use configurations:

- [minimal-values.yaml](examples/minimal-values.yaml) - minimum config to get started
- [full-values.yaml](examples/full-values.yaml) - production-ready with scaling, caching, and observability

## Key Configuration Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.imageTag` | Image tag for all services | Chart `appVersion` |
| `global.storage.endpoint` | S3-compatible storage endpoint | `""` |
| `global.storage.bucket` | S3 bucket name | `""` |
| `global.storage.region` | S3 region | `"auto"` |
| `global.observability.otlpEnabled` | Enable OTLP telemetry export | `false` |
| `global.observability.otlpEndpoint` | OTLP collector endpoint | `"ingest:4317"` |
| `global.s3Credentials.secretName` | Name of the S3 credentials secret | `"s3-credentials"` |
| `global.postgresCredentials.secretName` | Name of the Postgres credentials secret | `"postgres-credentials"` |
| `query.cache.size` | Query segment cache size | `"128Gi"` |
| `ingest.service.ports.otlpGrpc` | OTLP gRPC ingestion port | `4317` |
| `ingest.service.ports.otlpHttp` | OTLP HTTP ingestion port | `4318` |
| `janitor.config.mergerIntervalSeconds` | Interval between merge operations | `300` |

## Services

| Service | Description | Default Port |
|---------|-------------|-------------|
| meta | Metadata management | 9500 |
| query | Query engine | 9510 |
| ingest | Telemetry ingestion (OTLP) | 4317/4318 |
| janitor | Background maintenance | - |
| nursery | Baby segment management | 3002 |
| ui | Web interface | 80 |

## Template Debugging

To render the templates locally without installing:

```bash
helm template berserk berserk/berserk -f values.yaml
```

To debug with verbose output:

```bash
helm install berserk berserk/berserk --namespace bzrk -f values.yaml --dry-run --debug
```

## Releasing

When updating the container versions used, run:

```bash
scripts/set-app-version.sh
```

To release a new Chart version, run:

```bash
scripts/set-version.sh
```
