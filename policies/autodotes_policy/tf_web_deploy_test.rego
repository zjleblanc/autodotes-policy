package autodotes_policy_test

import rego.v1

import data.autodotes_policy

# -----------------------------------------------------------------------------
# Unit tests for tf_web_deploy.rego
#
# Example payloads: tests/data/autodotes_policy/payloads/tf_web_deploy.json
# (loaded as data.autodotes_policy.payloads.tf_web_deploy.* when running
# `opa test`, referenced below via the `autodotes_policy` import)
# -----------------------------------------------------------------------------

test_tf_web_deploy_allows_valid_vars if {
	payload := autodotes_policy.payloads.tf_web_deploy.valid
	result := autodotes_policy.tf_web_deploy with input as payload
	result.allowed == true
	count(result.violations) == 0
}

test_tf_web_deploy_denies_disallowed_key if {
	payload := autodotes_policy.payloads.tf_web_deploy.invalid_key
	result := autodotes_policy.tf_web_deploy with input as payload
	result.allowed == false
	count(result.violations) > 0
}

test_tf_web_deploy_denies_disallowed_value if {
	payload := autodotes_policy.payloads.tf_web_deploy.invalid_value
	result := autodotes_policy.tf_web_deploy with input as payload
	result.allowed == false
	count(result.violations) > 0
}
