package autodotes_policy

import rego.v1

# =============================================================================
# DISK EXPANSION POLICY
# =============================================================================
# Validates disk expansion requests by:
# 1. Ensuring disk_unit is one of the supported units
# 2. Ensuring the request actually grows the disk (disk_growth > 0) or targets
#    a concrete new size (disk_target > 0) — a request with neither is a
#    no-op that shouldn't bother anyone
# 3. Ensuring the request is traceable to a valid ServiceNow RITM
#    (see ritm_helpers.rego for the shared ritm_number/ritm_sys_id checks)
#
# Input structure expected:
# {
#   "extra_vars": {
#     "_host": "ao-vm-0106",
#     "disk_unit": "GB",
#     "disk_growth": 10,
#     "disk_target": -1,
#     "ritm_number": "RITM0000052",
#     "ritm_sys_id": "c199ca6fdd184e37ac1f6fb248c8a44a"
#   }
# }
#
# =============================================================================

# -----------------------------------------------------------------------------
# CONFIGURATION
# -----------------------------------------------------------------------------

# Define the units of measurement we know how to grow a disk by
allowed_disk_units := {"MB", "GB", "TB"}

# -----------------------------------------------------------------------------
# VALIDATION RULES
# -----------------------------------------------------------------------------

# Check for a missing or unsupported disk_unit
disk_expansion_violations contains msg if {
	unit := object.get(input_extra_vars, "disk_unit", "")
	not unit in allowed_disk_units
	msg := sprintf(
		"📏 '%v' is not a unit anyone has ever measured a disk in. Accepted units: [%v]",
		[unit, concat(", ", allowed_disk_units)],
	)
}

# Check that the request actually asks for more disk — either a positive
# growth amount or a positive absolute target size. Both left at (or below)
# zero means "please do nothing", which is not a job for automation.
disk_expansion_violations contains msg if {
	growth := to_number(object.get(input_extra_vars, "disk_growth", -1))
	not growth > 0
	target := to_number(object.get(input_extra_vars, "disk_target", -1))
	not target > 0
	msg := $"💾 disk_growth ({growth}) and disk_target ({target}) are both zilch. Did you just want to say hi?."
}

# Fold in the shared RITM traceability checks
disk_expansion_violations contains msg if {
	some msg in ritm_violations
}

# -----------------------------------------------------------------------------
# POLICY DECISION
# -----------------------------------------------------------------------------

# METADATA
# description: Validate disk expansion requests (unit, growth/target, RITM).
# entrypoint: true
default disk_expansion := {
	"allowed": true,
	"violations": [],
}

disk_expansion := result if {
	count(disk_expansion_violations) > 0
	result := {
		"allowed": false,
		"violations": disk_expansion_violations,
	}
}
