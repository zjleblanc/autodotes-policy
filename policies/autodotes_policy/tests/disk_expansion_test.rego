package autodotes_policy_test

import rego.v1

import data.autodotes_policy

# -----------------------------------------------------------------------------
# Unit tests for disk_expansion.rego
#
# Example payloads: tests/data/autodotes_policy/payloads/disk_expansion.json
# (loaded as data.autodotes_policy.payloads.disk_expansion.* when running
# `opa test`, referenced below via the `autodotes_policy` import)
# -----------------------------------------------------------------------------

test_disk_expansion_allows_valid_growth if {
	payload := autodotes_policy.payloads.disk_expansion.valid_growth
	result := autodotes_policy.disk_expansion with input as payload
	result.allowed == true
	count(result.violations) == 0
}

test_disk_expansion_allows_valid_target if {
	payload := autodotes_policy.payloads.disk_expansion.valid_target
	result := autodotes_policy.disk_expansion with input as payload
	result.allowed == true
	count(result.violations) == 0
}

test_disk_expansion_denies_invalid_unit if {
	payload := autodotes_policy.payloads.disk_expansion.invalid_unit
	result := autodotes_policy.disk_expansion with input as payload
	result.allowed == false
	count(result.violations) > 0
}

test_disk_expansion_denies_no_growth_or_target if {
	payload := autodotes_policy.payloads.disk_expansion.no_growth_or_target
	result := autodotes_policy.disk_expansion with input as payload
	result.allowed == false
	count(result.violations) > 0
}

test_disk_expansion_denies_missing_ritm if {
	payload := autodotes_policy.payloads.disk_expansion.missing_ritm
	result := autodotes_policy.disk_expansion with input as payload
	result.allowed == false
	count(result.violations) > 0
}

test_disk_expansion_denies_bad_ritm_format if {
	payload := autodotes_policy.payloads.disk_expansion.bad_ritm_format
	result := autodotes_policy.disk_expansion with input as payload
	result.allowed == false
	count(result.violations) > 0
}
