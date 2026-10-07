# Changelog

## 2026-10-07 — Fix Kustomize ComparisonError for OPA authz policy

### Fixed
- `k8s/base/kustomization.yaml` failed to generate manifests in CI (`ComparisonError`) because `policies/system/authz.rego` was outside the Kustomize root; moved the policy to `k8s/base/rego/system/authz.rego` and updated all documentation and manifest references to resolve the load restriction.

## 2026-10-07 — Add bearer token authentication for the OPA API

### Added
- `k8s/base/external-secret.yaml`: an `ExternalSecret` that reads an RSA public key from a `vault-backend` `ClusterSecretStore` and renders the OPA bundle/polling config plus a `keys` block into the `opa-config` Secret.
- `k8s/base/rego/system/authz.rego`: a `system.authz` policy, loaded locally by OPA, that default-denies and only allows authenticated `POST /v1/data/*` (policy evaluation) and `GET /v1/status` (monitoring).
- `docs/opa-authentication.md`: a step-by-step guide covering PKI setup, Vault integration, how the OPA config/deployment/authz policy fit together, minting an RS256 JWT for AAP, key rotation/revocation, and troubleshooting.
- `.gitignore` now excludes `*.pem`, `*.key`, and `*.pub` so key material generated while following the new docs can't be committed accidentally.

### Changed
- `k8s/base/deployment.yaml` runs OPA with `--authentication=token --authorization=basic`, mounts the new `authz.rego` ConfigMap at `/etc/opa/authz`, and mounts `opa-config` as a `Secret` instead of a `ConfigMap` since it now carries the JWT verification key.
- `k8s/base/kustomization.yaml`'s `configMapGenerator` now builds `opa-authz` from `k8s/base/rego/system/authz.rego` and adds `external-secret.yaml` to its resources; the `opa-config` Secret is managed by the `ExternalSecret` instead.
- `k8s/base/config.yaml` is kept only as a non-secret reference copy of the live config now templated inside `external-secret.yaml`.
- README's Security section, Prerequisites, and Configuration instructions now point to `docs/opa-authentication.md` and reflect the Secret-based `opa-config` and new `opa-authz` ConfigMap.

## 2026-10-07 — Configure production TLS and OpenShift Route

### Added
- An OpenShift Route manifest (`k8s/base/route.yaml`) for `opa.autodotes.com` with TLS passthrough.

### Changed
- The OPA certificate now uses the `letsencrypt-prod` cluster issuer and the public `opa.autodotes.com` DNS name.
- `k8s/base/kustomization.yaml` includes the new Route resource.

## 2026-10-07 — Fix OPA pod CrashLoopBackOff due to invalid TLS flag

### Fixed
- Updated the OPA deployment to use `--tls-private-key-file` instead of the deprecated/removed `--tls-key-file` flag, resolving a `CrashLoopBackOff` issue in newer OPA versions.

## 2026-10-06 — Adopt Kustomize overlays pattern for OPA server manifests

### Added
- A `k8s/overlays/default/` directory to hold environment-specific configuration, starting with the `opa` namespace.

### Changed
- The Kubernetes manifests now follow the Kustomize overlays pattern, separating common base resources from environment overrides.
- `k8s/base/kustomization.yaml` no longer hardcodes a namespace, making the base manifests environment-agnostic.
- The README reflects the new structure and updates the deployment instructions to use the `default` overlay.

## 2026-10-06 — Add OPA unit tests and Ansible Automation Platform integration docs

### Added
- OPA unit tests (`*_test.rego`) for all three policies, backed by full-schema example payloads under `tests/data/autodotes_policy/payloads/` that mirror the real Ansible Automation Platform (AAP) policy-enforcement input.
- `tests/README.md` documenting the test data layout, how to run and filter tests, and how to contribute new test cases.
- An `opa-test` pre-commit hook and a "Run unit tests" CI step, so a failing test blocks both local commits and the bundle build.
- README `Testing` and `Integrations` (Ansible Automation Platform) sections, including the AAP input/output payload schema and links to the official Red Hat docs.

### Changed
- The bundle workflow's build step now passes `--ignore '*_test.rego'` to `opa build` so test files never ship in production bundles, and its push trigger now also watches `tests/**`.
- `.regal/config.yaml` excepts `data.autodotes_policy.payloads.**` from the `unresolved-reference` rule, since Regal doesn't resolve data-file references.

## 2026-10-06 — Extract the Pages index generator into `registry/`

### Added
- A `registry/` directory with `generate_index.py`, `template.html`, and an `assets/` folder holding the OPA icon and the home/download icons as standalone PNG/SVG files, replacing a ~260-line inline Python heredoc in the bundle workflow.

### Changed
- The bundle workflow's "Write Pages index" step now just runs `python3 registry/generate_index.py`, and the push trigger also watches `registry/**`.
- README documents the new `registry/` layout.

## 2026-10-06 — Add pre-commit hooks and CI Rego linting

### Added
- A `.pre-commit-config.yaml` with hooks for file hygiene (pre-commit-hooks), secret scanning (gitleaks), Rego linting (Regal), and Rego syntax/formatting checks (`opa check --strict`, `opa fmt --fail`).
- A `.regal/config.yaml` carrying Regal's default rule set, ready for future per-rule customization.

### Changed
- The bundle workflow now runs `opa check --strict` and `regal lint` against all policies before building bundles.
- The README documents how to install and run the pre-commit hooks locally.

## 2026-10-06 — Publish a dark bundle index on GitHub Pages

### Added
- The bundle workflow writes a GitHub Pages index that lists each published bundle in a dark striped table, colored from the OPA logo. Each row shows the bundle name with the OPA icon, its size, a last-modified time in the browser’s local timezone, and a download link. A breadcrumb uses a home icon for the repo and a bundles segment.

### Changed
- Unchanged bundles copied from Pages keep the remote file time, so the index last-modified column reflects when that bundle was last published.

## 2026-10-06 — Rebuild only changed OPA bundles

### Changed
- The bundle workflow rebuilds only policy directories that changed in a push to `main`. A manual run, or a change to the workflow itself, still rebuilds every bundle. Unchanged bundles are copied from the published GitHub Pages site, and a failed fetch falls back to a local build.
- README section dividers were removed so the docs read as continuous sections.

## 2026-10-06 — Initialize the GitOps OPA policy repository

### Added
- Rego policies for the Autodotes environment: a default-deny rule, a production database-maintenance check that requires a `CHG-` ticket, and Terraform web-deploy checks that allow only known extra vars and VM sizes.
- A Kustomize base that deploys the OPA server on Kubernetes or MicroShift, with cert-manager TLS and polling of bundles published to GitHub Pages.
- A GitHub Actions workflow that builds one OPA bundle per directory under `policies/` and publishes it to GitHub Pages on push to `main`.
- Project README and MIT license.
