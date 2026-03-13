# Berserk Helm Charts

Helm charts for deploying [Berserk](https://github.com/berserkdb) - a high-performance observability data platform.

Check the [Berserk Docs](https://docs.bzrk.dev/docs/creating-a-cluster/) for installing the Helm chart

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
