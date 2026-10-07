package autodotes_policy

import rego.v1

# -----------------------------------------------------------------------------
# Shared RITM (ServiceNow Requested Item) validation helpers
#
# Several job templates (disk_expansion, restart_service, ...) are launched
# from a ServiceNow RITM and must carry enough breadcrumbs back to that ticket
# for traceability. This file centralizes that check so every policy that
# cares about "was this launched from a real ticket?" asks the same question
# the same way.
#
# Usage from another policy in this package:
#
#   some_policy_violations contains msg if {
#       some msg in ritm_violations
#   }
# -----------------------------------------------------------------------------

# Extract extra_vars from input with safe fallback to empty object
input_extra_vars := object.get(input, "extra_vars", {})

# RITM numbers from ServiceNow are "RITM" followed by a 7-digit, zero-padded
# sequence number, e.g. RITM0000052.
valid_ritm_number(ritm) if {
	regex.match(`^RITM[0-9]{7}$`, ritm)
}

# Missing ritm_number entirely
ritm_violations contains msg if {
	ritm := object.get(input_extra_vars, "ritm_number", "")
	ritm == ""
	msg := "🎫 No RITM number provided. No ticket, no work — this isn't a charity, Bob."
}

# Present but malformed ritm_number
ritm_violations contains msg if {
	ritm := object.get(input_extra_vars, "ritm_number", "")
	ritm != ""
	not valid_ritm_number(ritm)
	msg := $"🎫 '{ritm}' isn't a real RITM. Expected 'RITM' + 7 digits (e.g. RITM0000052)."
}

# Missing ritm_sys_id entirely
ritm_violations contains msg if {
	sys_id := object.get(input_extra_vars, "ritm_sys_id", "")
	sys_id == ""
	msg := "🆔 ritm_sys_id is missing. Without it, ServiceNow has no idea this ever happened — very spooky."
}
