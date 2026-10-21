package autodotes_policy_test

import rego.v1

import data.autodotes_policy

# -----------------------------------------------------------------------------
# Unit tests for deny.rego
#
# Example payloads: tests/data/autodotes_policy/payloads/deny.json
# (loaded as data.autodotes_policy.payloads.deny.* when running `opa test`,
# referenced below via the `autodotes_policy` import)
# -----------------------------------------------------------------------------

test_deny_blocks_generic_job if {
	payload := autodotes_policy.payloads.deny.generic
	result := autodotes_policy.deny with input as payload
	result.allowed == false
	count(result.violations) > 0
}

test_deny_blocks_even_with_no_input if {
	result := autodotes_policy.deny with input as {}
	result.allowed == false
	count(result.violations) > 0
}
