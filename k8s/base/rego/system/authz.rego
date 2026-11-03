package system

import rego.v1

# -----------------------------------------------------------------------------
# OPA server authorization policy.
#
# Evaluated by OPA on every API request when --authorization=basic is set.
# input.identity is populated only when --authentication=token has already
# verified the caller's bearer token (RS256 JWT, see external-secret.yaml);
# unauthenticated requests never reach this policy with a truthy identity.
#
# /health is always allowed by OPA regardless of these settings, so
# Kubernetes liveness/readiness probes are unaffected.
# -----------------------------------------------------------------------------

# Verify the caller's bearer JWT (audience must match OPA's expected aud).
authn if {
	jwt := input.identity
	constraints := {"audience": "opa.autodotes.com"}
	[valid, _, _] := io.jwt.decode_verify(jwt, constraints)
	valid == true
}

default authz := {"allow": false}

# Allow health checks without authentication.
authz := {"allow": true} if {
	input.method == "GET"
	input.path == ["health"]
}

# Allow policy evaluation calls (POST /v1/data/...) for authenticated callers.
# This is the only endpoint integrations need to query policy decisions.
authz := {"allow": true} if {
	authn
	input.method == "POST"
	input.path[0] == "v1"
	count(input.path) >= 2
	input.path[1] == "data"
}

# Allow bundle/policy status checks (GET /v1/status) for authenticated
# monitoring clients.
authz := {"allow": true} if {
	authn
	input.method == "GET"
	input.path == ["v1", "status"]
}
