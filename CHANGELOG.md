# Changelog

## 2026-10-21 — Refactor policy package structure into validators and tests subdirectories

### Changed
- Policy package layout refactored: moved validator logic to a `validators/` subdirectory and unit test logic to a `tests/` subdirectory within each bundle directory.
- Shared validators now reside in a `<package>.validators` sub-namespace (e.g., `autodotes_policy.validators`), requiring explicit imports in policy files.
- `.github/workflows/bundle.yaml`: updated `opa build` to explicitly ignore the new `tests/` subdirectories.
- `.cursor/rules/policy-validator-functions.mdc` and `.cursor/skills/create-policy/SKILL.md` updated to enforce and scaffold the new directory layout and import pattern.
- `README.md` and `tests/README.md` updated to reflect the new project structure.
- `.regal/config.yaml`: disabled `directory-package-mismatch` to support the `tests/` subdirectory convention.
- All Rego files auto-formatted with `opa fmt`.

## 2026-10-21 — Add job failure notification policy and refactor shared validators

### Added
- `policies/autodotes_policy/job_failure_notification.rego`: a new policy ensuring job failure notifications carry valid email recipients, a required RITM ticket, and no forbidden HTML tags in the message body.
- `policies/autodotes_policy/format_validators.rego`: shared validation logic for email addresses, HTML tags, and other generic string formats.
- `.cursor/rules/policy-validator-functions.mdc`: a new project rule enforcing that shared validator functions live in `*_validators.rego` files rather than being defined inline.
- `.cursor/skills/create-policy/SKILL.md`: a new Cursor skill for scaffolding new OPA policies following the project's directory structure and naming conventions.

### Changed
- `policies/autodotes_policy/ritm_helpers.rego` has been renamed to `ritm_validators.rego` to match the new naming convention for shared validator logic.
- `policies/autodotes_policy/disk_expansion.rego` and `restart_service.rego` updated to reference the new `ritm_validators.rego` location.
- `registry/generate_index.py`: the bundle registry now excludes `*_validators.rego` files (instead of `*_helpers.rego`) from the per-bundle policy list.

## 2026-10-15 — Refine bundle registry detail rows and add site link to README

### Added
- `README.md`: bundle registry link (`zjleblanc.github.io/autodotes-policy`) added below the CI badge for quick access.

### Changed
- `registry/generate_index.py`: helper files (`*_helpers.rego`) are now excluded from the per-bundle policy list shown in expanded detail rows.
- `registry/generate_index.py`: rule names in expanded detail rows are displayed without the `.rego` extension.

## 2026-10-07 — Scope OPA bundles and fix deployment spec

### Added
- `policies/autodotes_policy/.manifest`: scopes the `autodotes_policy` bundle to its own root, preventing it from clobbering the `system.authz` policy and causing `500 Internal Server Error` on health checks.
- `.cursor/rules/policy-bundle-manifest.mdc`: a new Cursor rule ensuring all future policy directories include a `.manifest` to prevent root-clobbering bugs.

### Fixed
- `k8s/base/deployment.yaml`: moved `revisionHistoryLimit` to the correct `spec.revisionHistoryLimit` location.

## 2026-10-07 — Fix OPA health checks and structured authz response

### Fixed
- `k8s/base/rego/system/authz.rego`: restored the structured `{"allow": true/false}` response format for the `system.authz` policy. Newer OPA versions (like 1.21.1) return a `500 Internal Server Error` when `--authorization=basic` is enabled if the policy returns a simple boolean instead of the expected object.
- `k8s/base/external-secret.yaml`: fixed RSA public key templating by using a block scalar and `indent` function, ensuring multiline PEM keys are correctly formatted in the generated `opa-config` Secret. This resolves `500 Internal Server Error` responses when OPA attempts to load an invalid key.

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
