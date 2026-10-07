package autodotes_policy

import rego.v1

# -----------------------------------------------------------------------------
# Demo: database maintenance job — change control on launch-time inputs
#
# Scenario: A job template runs database maintenance (migrations, index
# rebuilds, etc.). Jobs pass target context through extra_vars, the same JSON
# AAP includes when it queries OPA at enforcement time.
#
# Policy: any run that declares a production target must include a change
# ticket in the format CM teams expect (CHG-). Staging and other
# environments are not blocked, mirroring how you gate risky automation without
# slowing lower environments.
#
# In AAP, attach: autodotes_policy/demo_database_maintenance
# -----------------------------------------------------------------------------

input_extra_vars := object.get(input, "extra_vars", {})

# Treat common spellings as production without relying on string builtins
is_production_target if {
	t := input_extra_vars.demo_target_environment
	t in {
		"production",
		"prod",
		"Production",
		"PROD",
		"PRODUCTION",
	}
}

# Valid corporate change record (simplified pattern for the demo)
valid_change_ticket(ticket) if {
	regex.match(`^CHG-[0-9]+$`, ticket)
}

# Use a rule name unique to this policy. In OPA, `violations contains` in the
# same package as other policies (e.g. tf_web_deploy.rego) would merge into one
# set and incorrectly block unrelated evaluations.
demo_database_maintenance_violations contains msg if {
	is_production_target
	ticket := object.get(input_extra_vars, "demo_change_ticket", "")
	not valid_change_ticket(ticket)
	quoted_ticket := json.marshal(ticket)
	requirement := "required format CHG-12345 style ticket (example CHG-4412)"
	msg := $"production change control: missing or invalid change_ticket ({quoted_ticket}); {requirement}"
}

# METADATA
# description: Require a CHG- ticket when database maintenance targets production.
# entrypoint: true
default demo_database_maintenance := {
	"allowed": true,
	"violations": [],
}

demo_database_maintenance := result if {
	count(demo_database_maintenance_violations) > 0
	result := {
		"allowed": false,
		"violations": demo_database_maintenance_violations,
	}
}
