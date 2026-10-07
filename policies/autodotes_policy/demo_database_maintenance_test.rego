package autodotes_policy_test

import rego.v1

import data.autodotes_policy

# -----------------------------------------------------------------------------
# Unit tests for demo_database_maintenance.rego
#
# Example payloads: tests/data/autodotes_policy/payloads/demo_database_maintenance.json
# (loaded as data.autodotes_policy.payloads.demo_database_maintenance.* when
# running `opa test`, referenced below via the `autodotes_policy` import)
# -----------------------------------------------------------------------------

test_demo_database_maintenance_allows_prod_with_valid_ticket if {
	payload := autodotes_policy.payloads.demo_database_maintenance.prod_with_valid_ticket
	result := autodotes_policy.demo_database_maintenance with input as payload
	result.allowed == true
	count(result.violations) == 0
}

test_demo_database_maintenance_denies_prod_missing_ticket if {
	payload := autodotes_policy.payloads.demo_database_maintenance.prod_missing_ticket
	result := autodotes_policy.demo_database_maintenance with input as payload
	result.allowed == false
	count(result.violations) > 0
}

test_demo_database_maintenance_denies_prod_invalid_ticket_format if {
	payload := autodotes_policy.payloads.demo_database_maintenance.prod_invalid_ticket_format
	result := autodotes_policy.demo_database_maintenance with input as payload
	result.allowed == false
	count(result.violations) > 0
}

test_demo_database_maintenance_allows_staging_without_ticket if {
	payload := autodotes_policy.payloads.demo_database_maintenance.staging_no_ticket
	result := autodotes_policy.demo_database_maintenance with input as payload
	result.allowed == true
	count(result.violations) == 0
}
