package autodotes_policy

import rego.v1

# =============================================================================
# TERRAFORM WEB DEPLOYMENT POLICY
# =============================================================================
# This policy validates Terraform web deployment configurations by:
# 1. Ensuring only allowed extra_vars keys are provided
# 2. Validating that extra_vars values are within allowed ranges
#
# Input structure expected:
# {
#   "extra_vars": {
#     "az_ssh_pubkey": "<ssh_key>",
#     "az_web_vm_size": "Standard_DS1_v2"
#   }
# }
# =============================================================================

# -----------------------------------------------------------------------------
# CONFIGURATION
# -----------------------------------------------------------------------------

# Define allowed keys for extra_vars
allowed_extra_var_keys := {
	"az_ssh_pubkey",
	"az_web_vm_size"
}

# Define allowed values for specific keys
allowed_extra_var_values := {
	"az_web_vm_size": {
		"Standard_DS1_v2",
		"Standard_DS2_v2",
		"Standard_DS3_v2",
	}
}

# -----------------------------------------------------------------------------
# DEFAULT POLICY RESULT
# -----------------------------------------------------------------------------

default tf_web_deploy := {
	"allowed": true,
	"violations": [],
}

# -----------------------------------------------------------------------------
# INPUT PROCESSING
# -----------------------------------------------------------------------------

# Extract extra_vars from input with safe fallback to empty object
input_extra_vars := object.get(input, "extra_vars", {})

# -----------------------------------------------------------------------------
# VALIDATION RULES
# -----------------------------------------------------------------------------

# Check for disallowed extra_vars keys
violations contains violation_message if {
	# Find keys that are not in the allowed list
	disallowed_keys := {key |
		input_extra_vars[key]
		not key in allowed_extra_var_keys
	}

	count(disallowed_keys) > 0

	violation_message := sprintf(
		"🙅 Disallowed extra_vars provided: [%v]. Allowed keys: [%v]",
		[concat(",", disallowed_keys), concat(", ", allowed_extra_var_keys)],
	)
}

# Check for invalid extra_vars values
violations contains violation_message if {
	# Find keys with values not in the allowed list
	some key in object.keys(allowed_extra_var_values)
	provided_value := input_extra_vars[key]
	not provided_value in allowed_extra_var_values[key]

	violation_message := sprintf(
		"🙅 '%v' provided for '%v' not in accepted values: [%v]",
		[provided_value, key, concat(", ", allowed_extra_var_values[key])],
	)
}

# -----------------------------------------------------------------------------
# FINAL POLICY DECISION
# -----------------------------------------------------------------------------

# Override default result when violations exist
tf_web_deploy := result if {
	count(violations) > 0
	result := {
		"allowed": false,
		"violations": violations,
	}
}
