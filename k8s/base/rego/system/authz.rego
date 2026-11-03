package system

import rego.v1

# -----------------------------------------------------------------------------
# OPA server authorization policy.
#
# Evaluated by OPA on every API request when --authorization=basic is set.
# --authentication=token only extracts the Bearer token into input.identity;
# this policy verifies the RS256 signature (data.system.jwt_cert from the
# opa-config Secret) and required claims before allowing access.
#
# /health is always allowed by OPA regardless of these settings, so
# Kubernetes liveness/readiness probes are unaffected.
# -----------------------------------------------------------------------------

# Verify the caller's bearer JWT (signature + audience).
authn if {
	[valid, _, _] := io.jwt.decode_verify(input.identity, {
		"cert": data.system.jwt_cert,
		"aud": "opa.autodotes.com",
	})
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
