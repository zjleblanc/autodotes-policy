# Changelog

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
