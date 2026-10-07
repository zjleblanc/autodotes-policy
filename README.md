# autodotes-policy

> GitOps-driven policy enforcement for Ansible Automation Platform, powered by Open Policy Agent.

Write a Rego rule, push to `main`, and your policy is live — no manual deploys, no pod restarts.

[![Build and Publish OPA Bundle](https://github.com/zjleblanc/autodotes-policy/actions/workflows/bundle.yaml/badge.svg)](https://github.com/zjleblanc/autodotes-policy/actions/workflows/bundle.yaml)

## Table of Contents

- [About](#about)
- [Features](#features)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Configuration](#configuration)
- [Security](#security)
- [How to Contribute](#how-to-contribute)
- [License](#license)

## About

**autodotes-policy** is a GitOps repository that manages [Open Policy Agent](https://www.openpolicyagent.org/) (OPA) policies for the Autodotes environment. It gives you a single source of truth for all your authorization rules: policies live in this repo as human-readable [Rego](https://www.openpolicyagent.org/docs/latest/policy-language/) files, a GitHub Actions workflow automatically builds and publishes them as OPA bundles, and a running OPA server hot-reloads them — no manual steps required.

## Features

| Feature | Description |
|---|---|
| 🔄 **Automated bundle publishing** | GitHub Actions builds an OPA bundle for every policy folder on every push to `main` |
| 🔥 **Hot reload** | The OPA server polls GitHub Pages on a configurable interval and reloads policies in-place — zero downtime, no pod restart |
| 📦 **Multi-bundle support** | Each subdirectory under `policies/` becomes its own independently versioned bundle |
| 🔒 **TLS out of the box** | The OPA server is exposed over HTTPS via cert-manager and Let's Encrypt |
| ☸️ **Kubernetes-native** | Deployable to any Kubernetes cluster (or MicroShift) using a single Kustomize command |
| ➕ **Extensible** | Add a new policy set by creating a new folder — the CI pipeline discovers it automatically |

## Architecture

Here's how a policy change flows from your editor all the way to enforcement:

```mermaid
flowchart LR
    A[👩‍💻 Edit .rego file\nand push to main] --> B[GitHub Actions\nopa build per bundle]
    B --> C[GitHub Pages\nbundles/*.bundle.tar.gz]
    C -->|HTTPS polling\nconfigurable interval| D[OPA Server\non MicroShift]
    D -->|Policy enforced| E[🛡️ Ansible / API callers]
```

> The OPA server polls each bundle URL on an interval. When a new bundle is available it's applied instantly — **no ConfigMap changes, no rolling restarts**.

## Project Structure

```
autodotes-policy/
├── policies/                          # All Rego policy source files
│   └── autodotes_policy/              # One folder = one OPA bundle
│       ├── deny.rego                  # Default-deny catch-all rule
│       ├── demo_database_maintenance.rego
│       └── tf_web_deploy.rego
│
├── k8s/
│   └── base/                          # Kustomize manifests for the OPA server
│       ├── deployment.yaml            # OPA Deployment (TLS + bundle config)
│       ├── config.yaml                # Bundle sources & polling intervals
│       ├── service.yaml               # ClusterIP Service (port 8443)
│       ├── certificate.yaml           # cert-manager Certificate resource
│       └── kustomization.yaml         # Namespace, resources, ConfigMap generator
│
├── registry/                          # Pages index generator assets
│   ├── generate_index.py              # Builds index.html files for GitHub Pages
│   ├── template.html                  # HTML template for the bundle listing page
│   └── assets/
│       ├── opa-icon.png               # OPA icon used in the bundle listing
│       ├── home-icon.svg              # Breadcrumb home icon (inlined into HTML)
│       └── download-icon.svg          # Download icon (inlined into HTML)
│
└── .github/
    └── workflows/
        └── bundle.yaml                # CI: build & publish all bundles to Pages
```

**Adding a new policy bundle** is as simple as creating a new subdirectory under `policies/`. The workflow discovers it automatically on the next push.

## Getting Started

### Prerequisites

Before deploying, make sure you have:

- A Kubernetes (or MicroShift) cluster with `kubectl` or `oc` access
- [cert-manager](https://cert-manager.io/docs/installation/) installed on the cluster
- A `letsencrypt` `ClusterIssuer` that can issue certificates for `opa.autodotes.com`
- DNS for `opa.autodotes.com` pointing at your cluster
- GitHub Pages enabled on this repo (**Settings → Pages → Source: GitHub Actions**)

### Deploy the OPA server

```sh
# Using OpenShift CLI
kubectl kustomize k8s/base | oc apply -f -

# Using plain kubectl
kubectl kustomize k8s/base | kubectl apply -f -
```

This creates the `opa` namespace and deploys:
- The OPA server `Deployment`
- A `ClusterIP` Service on port `8443`
- A cert-manager `Certificate` for `opa.autodotes.com`
- The `opa-config` ConfigMap with bundle polling configuration

### Verify it's running

```sh
# Check pods, service, and certificate status
kubectl -n opa get pods,svc,certificate

# Tail the OPA server logs
kubectl -n opa logs deploy/opa
```

Once the pod is `Running` and the certificate shows `Ready: True`, OPA is reachable at:
- **Inside the cluster:** `https://opa.opa.svc:8443`
- **Externally (if routed):** `https://opa.autodotes.com`

Confirm the policy bundle loaded by checking the logs or calling `GET /v1/status` on the OPA API.

## Configuration

### Adding a new policy bundle

1. Create a new subdirectory under `policies/` — the folder name becomes the bundle name.

    ```
    policies/my_new_policy/
    └── rules.rego
    ```

2. Push to `main`. The CI workflow builds and publishes the bundle automatically.

3. Tell OPA to load it by adding a matching entry under `bundles:` in [`k8s/base/config.yaml`](k8s/base/config.yaml).

### Bundle polling interval

Edit [`k8s/base/config.yaml`](k8s/base/config.yaml) to adjust how frequently OPA checks for policy updates:

```yaml
bundles:
  autodotes_policy:
    polling:
      min_delay_seconds: 30
      max_delay_seconds: 120
```

### Updating an existing policy

Simply edit the `.rego` files under `policies/<name>/` and push to `main`. No changes to `k8s/` are needed — OPA picks up the new bundle on the next poll cycle.

## Security

- **TLS everywhere** — the OPA server only accepts connections over HTTPS (port `8443`). Certificates are automatically provisioned and renewed by cert-manager.
- **Least-privilege CI** — the GitHub Actions workflow requests only `pages: write` and `id-token: write`; all other permissions are read-only.
- **Default-deny posture** — the `deny.rego` rule blocks all job execution unless an explicit allow rule overrides it, following a safe-by-default approach.
- **No secrets in repo** — TLS key material is managed entirely by cert-manager and mounted into the pod at runtime. No credentials are stored in this repository.

## How to Contribute

Contributions are welcome! Here's how to get started:

1. **Fork** this repository and create a feature branch off `main`.
2. **Add or edit** Rego policies under `policies/`.
3. **Test your policies locally** using the [OPA CLI](https://www.openpolicyagent.org/docs/latest/#running-opa):
    ```sh
    opa eval -b policies/autodotes_policy -d input.json 'data.autodotes_policy'
    ```
4. **Open a pull request** — the CI workflow will lint and validate the bundle build automatically.

Please keep policy changes focused and include a short description in your PR of what the rule enforces and why.

### Pre-commit hooks

This repo ships a [`.pre-commit-config.yaml`](.pre-commit-config.yaml) that catches common issues before they reach CI:

| Hook | Purpose |
|---|---|
| `pre-commit-hooks` | Trailing whitespace, EOF newlines, YAML syntax, large files, merge conflict markers |
| [`gitleaks`](https://github.com/gitleaks/gitleaks) | Scans staged changes for hardcoded secrets |
| [`regal-lint`](https://github.com/open-policy-agent/regal) | Lints Rego style and best practices |
| `opa-check` | Runs `opa check --strict` for Rego syntax/strict-mode errors |
| `opa-fmt` | Runs `opa fmt --fail` to enforce consistent Rego formatting |

Setup (one-time, per clone) — requires [`pre-commit`](https://pre-commit.com/) and the [`opa`](https://www.openpolicyagent.org/docs/latest/#running-opa) CLI on your `PATH`:

```sh
pip install pre-commit
pre-commit install
```

Hooks run automatically on `git commit`. To run them against all files on demand:

```sh
pre-commit run --all-files
```

## License

This project is open source. See [LICENSE](LICENSE) for details.