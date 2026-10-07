# OPA Bearer Token Authentication

This document covers the full setup for securing the OPA server's API with
RS256-signed JWT bearer tokens: generating the key pair, storing it in
Vault, how the Kubernetes manifests wire everything together, and how to
mint a token for Ansible Automation Platform (AAP).

See the main [README's Security section](../README.md#security) for a
summary; this doc is the detailed reference.

## Contents

- [Overview](#overview)
- [1. PKI setup](#1-pki-setup)
- [2. Vault integration](#2-vault-integration)
- [3. OPA server configuration](#3-opa-server-configuration)
- [4. Minting a JWT for AAP](#4-minting-a-jwt-for-aap)
- [5. Rotation and revocation](#5-rotation-and-revocation)
- [6. Testing and troubleshooting](#6-testing-and-troubleshooting)

## Overview

```mermaid
sequenceDiagram
    participant Vault as HashiCorp Vault
    participant ESO as External Secrets Operator
    participant OPA as OPA Server
    participant AAP as Ansible Automation Platform

    Vault->>ESO: RSA public key (secret/data/autodotes/opa)
    ESO->>OPA: Secret opa-config (config.yaml with keys.aap.key)
    Note over Vault: RSA private key stays in Vault;<br/>used only to sign JWTs for AAP
    AAP->>OPA: POST /v1/data/autodotes_policy/...<br/>Authorization: Bearer [JWT]
    OPA->>OPA: --authentication=token verifies<br/>JWT signature (RS256 public key)
    OPA->>OPA: --authorization=basic evaluates<br/>system.authz (k8s/base/authz.rego)
    OPA-->>AAP: 200 {allowed, violations} or 401/403
```

OPA runs with two independent, stacked controls (see
[`k8s/base/deployment.yaml`](../k8s/base/deployment.yaml)):

| Flag | Purpose |
|---|---|
| `--authentication=token` | Verifies the JWT signature in `Authorization: Bearer <jwt>` on every request (except `/health`, which OPA always leaves open for liveness/readiness probes). Rejects invalid/unsigned/malformed tokens with `401`. |
| `--authorization=basic` | After authentication succeeds, evaluates the `system.authz` policy ([`k8s/base/authz.rego`](../k8s/base/authz.rego)) to decide whether this specific authenticated request is permitted. Rejects disallowed requests with `403`. |

RS256 (asymmetric) is used instead of a shared/symmetric secret so that OPA
only ever holds the **public** verification key. The **private** signing
key never leaves Vault, so a compromised OPA pod cannot be used to mint new
valid tokens.

## 1. PKI setup

Generate a 2048-bit (or stronger) RSA key pair dedicated to this
integration. Do this somewhere secure (not in this repo, not in CI) — the
private key only needs to touch Vault and whatever process mints tokens.

```sh
# Private key
openssl genrsa -out opa-aap.key 2048

# Public key (derived from the private key)
openssl rsa -in opa-aap.key -pubout -out opa-aap.pub

# Sanity check
openssl rsa -in opa-aap.key -check -noout
```

You should end up with:

- `opa-aap.key` — PEM-encoded RSA **private** key. Goes into Vault only. Used solely to sign JWTs.
- `opa-aap.pub` — PEM-encoded RSA **public** key. Goes into Vault, then gets pulled into the cluster by `ExternalSecret` for OPA to verify signatures.

Treat `opa-aap.key` as highly sensitive: anyone holding it can mint tokens
that OPA will accept as valid, authenticated AAP requests.

## 2. Vault integration

Store both keys under a single Vault KV v2 path:

```sh
vault kv put secret/autodotes/opa \
  rsa_public_key=@opa-aap.pub \
  rsa_private_key=@opa-aap.key
```

This matches the path/property referenced in
[`k8s/base/external-secret.yaml`](../k8s/base/external-secret.yaml):

```yaml
data:
  - secretKey: public_key
    remoteRef:
      key: gitops/opa/jwt-sign
      property: public_key
```

### Vault read policy (least privilege)

Scope the token/role the `vault-backend` `ClusterSecretStore` uses down to
read-only access on this one path:

```hcl
# opa-external-secrets-policy.hcl
path "secret/data/autodotes/opa" {
  capabilities = ["read"]
}
```

```sh
vault policy write opa-external-secrets opa-external-secrets-policy.hcl
```

Bind that policy to whichever auth method the `ClusterSecretStore` uses
(Kubernetes auth, AppRole, etc.) — this repo does not create the
`ClusterSecretStore` itself; it only assumes one named `vault-backend`
already exists with read access to this path. See the
[External Secrets Operator docs](https://external-secrets.io/latest/provider/hashicorp-vault/)
for provider-specific `ClusterSecretStore` configuration.

### Never pull the private key into the cluster

Only `rsa_public_key` is referenced by
[`k8s/base/external-secret.yaml`](../k8s/base/external-secret.yaml). Do not
add `rsa_private_key` to that `ExternalSecret` or any other cluster-facing
manifest — it only needs to exist in Vault and in whatever offline/CI
process mints tokens (see [Section 4](#4-minting-a-jwt-for-aap)).

## 3. OPA server configuration

Four files work together:

| File | Role |
|---|---|
| [`k8s/base/config.yaml`](../k8s/base/config.yaml) | Non-secret reference copy of the bundle/polling config. **Not deployed as-is** — kept in sync manually with the template below so the repo documents the full config in one readable place. |
| [`k8s/base/external-secret.yaml`](../k8s/base/external-secret.yaml) | The `ExternalSecret` that actually renders the live config. Templates the bundle/polling config *plus* a `keys` block containing the Vault-sourced public key into a Secret named `opa-config`. |
| [`k8s/base/deployment.yaml`](../k8s/base/deployment.yaml) | Mounts `opa-config` (now a `Secret`, not a `ConfigMap`) at `/etc/opa/config.yaml`, mounts the `authz.rego` ConfigMap at `/etc/opa/authz/`, and passes `--authentication=token --authorization=basic /etc/opa/authz/` to `opa run`. |
| [`k8s/base/authz.rego`](../k8s/base/authz.rego) | The `system.authz` package OPA evaluates per request once authenticated. |

The relevant `keys` block in the `ExternalSecret` template:

```yaml
keys:
  aap:
    key: "{{ .rsa_public_key }}"
    algorithm: RS256
```

`aap` here is just the key's name inside OPA's config — it doesn't have to
match anything on the AAP side. OPA tries each configured key against the
JWT's signature; with only one key configured, that's the one used.

The `system.authz` policy ([`k8s/base/authz.rego`](../k8s/base/authz.rego))
is intentionally narrow — default-deny, then two explicit allows:

```rego
default authz := {"allow": false}

# Allow policy evaluation calls (POST /v1/data/...) for authenticated callers.
authz := {"allow": true} if {
	input.identity
	input.method == "POST"
	input.path[0] == "v1"
	input.path[1] == "data"
}

# Allow bundle/policy status checks (GET /v1/status) for authenticated
# monitoring clients.
authz := {"allow": true} if {
	input.identity
	input.method == "GET"
	input.path == ["v1", "status"]
}
```

`input.identity` is only truthy when `--authentication=token` has already
verified the JWT signature — this policy never sees raw headers or
unauthenticated requests. Everything other than `POST /v1/data/*` and
`GET /v1/status` (policy upload/delete, arbitrary data writes, `/v1/compile`,
etc.) is denied even for a validly authenticated caller.

Because the ConfigMap holding `authz.rego` is generated by Kustomize's
`configMapGenerator` ([`k8s/base/kustomization.yaml`](../k8s/base/kustomization.yaml)),
it gets a content hash suffix and the Deployment picks up changes to the
policy automatically on `kubectl apply`.

## 4. Minting a JWT for AAP

AAP's OPA integration sends a single static bearer token with every
request, so you mint one JWT and configure it once in AAP (rotating only
when you choose to, see [Section 5](#5-rotation-and-revocation)).

### Recommended claims

```json
{
  "sub": "aap",
  "iss": "autodotes",
  "aud": "opa.autodotes.com"
}
```

- `sub`/`iss`/`aud` identify the caller for auditing — `authz.rego` doesn't
  currently check them, but they're cheap to add and useful if you later
  want to tighten the policy to a specific subject.
- Omit `exp` for a non-expiring token (simplest; rotate by rotating the key
  pair instead). Add `exp` if you want tokens that must be periodically
  reissued regardless of key rotation.

### Signing the token

Any JWT library that supports RS256 works. Example using Python's
[`PyJWT`](https://pyjwt.readthedocs.io/):

```sh
pip install pyjwt cryptography
```

```python
import jwt

with open("opa-aap.key") as f:
    private_key = f.read()

token = jwt.encode(
    {"sub": "aap", "iss": "autodotes", "aud": "opa.autodotes.com"},
    private_key,
    algorithm="RS256",
)

print(token)
```

Or with the [`jwt-cli`](https://github.com/mike-engel/jwt-cli) tool:

```sh
jwt encode --alg RS256 --rsa-private-key-file opa-aap.key \
  --sub aap --iss autodotes --aud opa.autodotes.com
```

### Configuring AAP

In AAP's policy-enforcement / OPA integration settings:

- **URL:** `https://opa.autodotes.com`
- **Bearer Token:** the JWT string produced above

AAP will send this token as `Authorization: Bearer <jwt>` on every policy
evaluation request.

## 5. Rotation and revocation

OPA's token authentication has no built-in revocation list — a JWT is valid
until it fails signature verification or (if present) its `exp` claim
passes. There are two ways to invalidate tokens:

1. **Rotate the key pair (immediate, revokes everything).** Generate a new
   RSA pair (Section 1), update `rsa_public_key`/`rsa_private_key` in Vault
   (Section 2), and mint a new token with the new private key. The
   `ExternalSecret` refreshes hourly (`refreshInterval: 1h` in
   [`k8s/base/external-secret.yaml`](../k8s/base/external-secret.yaml)), so
   the new public key reaches OPA automatically; force an immediate refresh
   with:

   ```sh
   kubectl -n opa annotate externalsecret opa-config \
     force-sync=$(date +%s) --overwrite
   ```

   Every previously issued token (including any leaked one) stops
   verifying as soon as OPA picks up the new public key. Update AAP with
   the newly minted token.

2. **Use `exp` claims (gradual, no action required).** If tokens are minted
   with an expiration, they stop working on their own; reissue and update
   AAP before expiry.

For routine hygiene, prefer periodic key rotation (option 1) on a schedule
(e.g. every 90 days) combined with `exp` claims as a backstop.

## 6. Testing and troubleshooting

```sh
# /health is always open — should succeed with no token
curl -sk https://opa.autodotes.com/health

# A request with no token should be rejected (401)
curl -sk -X POST https://opa.autodotes.com/v1/data/autodotes_policy/deny \
  -d '{"input": {}}'

# A request with a valid token should succeed (200)
TOKEN="<jwt-from-section-4>"
curl -sk -X POST https://opa.autodotes.com/v1/data/autodotes_policy/deny \
  -H "Authorization: Bearer ${TOKEN}" \
  -d '{"input": {}}'

# A disallowed method/path with a valid token should be forbidden (403),
# e.g. attempting to upload a policy module:
curl -sk -X PUT https://opa.autodotes.com/v1/policies/test \
  -H "Authorization: Bearer ${TOKEN}" \
  --data-binary 'package test'
```

If requests unexpectedly fail:

```sh
# Confirm the Secret rendered by ExternalSecret contains the keys block
kubectl -n opa get secret opa-config -o jsonpath='{.data.config\.yaml}' | base64 -d

# Confirm the ExternalSecret itself is syncing cleanly
kubectl -n opa describe externalsecret opa-config

# Tail OPA logs for authentication/authorization decision errors
kubectl -n opa logs deploy/opa
```

Common causes of unexpected `401`s: the JWT was signed with a different
key than the one currently in Vault, or the `ExternalSecret` hasn't
refreshed yet after a key rotation. Common causes of unexpected `403`s: the
request's method/path isn't one of the two explicitly allowed in
[`k8s/base/authz.rego`](../k8s/base/authz.rego).
