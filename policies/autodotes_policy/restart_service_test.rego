package autodotes_policy_test

import rego.v1

import data.autodotes_policy

# -----------------------------------------------------------------------------
# Unit tests for restart_service.rego
#
# Example payloads: tests/data/autodotes_policy/payloads/restart_service.json
# (loaded as data.autodotes_policy.payloads.restart_service.* when running
# `opa test`, referenced below via the `autodotes_policy` import)
# -----------------------------------------------------------------------------

test_restart_service_allows_valid_service if {
	payload := autodotes_policy.payloads.restart_service.valid_service
	result := autodotes_policy.restart_service with input as payload
	result.allowed == true
	count(result.violations) == 0
}

test_restart_service_denies_banned_service if {
	payload := autodotes_policy.payloads.restart_service.banned_service
	result := autodotes_policy.restart_service with input as payload
	result.allowed == false
	count(result.violations) > 0
	"What are you thinking? Bill Lumbergh will fire you on the spot! 🔥" in result.violations
}

test_restart_service_denies_missing_service if {
	payload := autodotes_policy.payloads.restart_service.missing_service
	result := autodotes_policy.restart_service with input as payload
	result.allowed == false
	count(result.violations) > 0
}

test_restart_service_denies_missing_ritm if {
	payload := autodotes_policy.payloads.restart_service.missing_ritm
	result := autodotes_policy.restart_service with input as payload
	result.allowed == false
	count(result.violations) > 0
}

test_restart_service_denies_bad_ritm_sys_id if {
	payload := autodotes_policy.payloads.restart_service.bad_ritm_sys_id
	result := autodotes_policy.restart_service with input as payload
	result.allowed == false
	count(result.violations) > 0
}
