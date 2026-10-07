# Changelog

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
