package autodotes_policy

import rego.v1

# =============================================================================
# RESTART SERVICE POLICY
# =============================================================================
# Validates service restart requests by:
# 1. Ensuring a service_name was actually provided
# 2. Ensuring service_name is not on the banned-service list (looking at you,
#    tps_reporter)
# 3. Ensuring the request is traceable to a valid ServiceNow RITM
#    (see ritm_helpers.rego for the shared ritm_number/ritm_sys_id checks)
#
# Input structure expected:
# {
#   "extra_vars": {
#     "_host": "ao-vm-0106",
#     "ritm_number": "RITM0000051",
#     "ritm_sys_id": "b3eb037aee394fa49065cd0940834050",
#     "service_name": "valkey"
#   }
# }
#
# =============================================================================

# -----------------------------------------------------------------------------
# CONFIGURATION
# -----------------------------------------------------------------------------

# Services nobody is allowed to restart via this job template, on pain of
# a stern memo about TPS reports.
banned_services := {"tps_reporter"}

# -----------------------------------------------------------------------------
# VALIDATION RULES
# -----------------------------------------------------------------------------

# Missing service_name
restart_service_violations contains msg if {
	svc := object.get(input_extra_vars, "service_name", "")
	svc == ""
	msg := "🤷 No service_name provided. Maybe you should restart yourself."
}

# Banned service — yeah, we're doing the bit.
restart_service_violations contains msg if {
	svc := object.get(input_extra_vars, "service_name", "")
	svc in banned_services
	msg := "What are you thinking? Bill Lumbergh will fire you on the spot! 🔥"
}

# Fold in the shared RITM traceability checks
restart_service_violations contains msg if {
	some msg in ritm_violations
}

# -----------------------------------------------------------------------------
# POLICY DECISION
# -----------------------------------------------------------------------------

# METADATA
# description: Validate service restart requests (service name, banned list, RITM).
# entrypoint: true
default restart_service := {
	"allowed": true,
	"violations": [],
}

restart_service := result if {
	count(restart_service_violations) > 0
	result := {
		"allowed": false,
		"violations": restart_service_violations,
	}
}
