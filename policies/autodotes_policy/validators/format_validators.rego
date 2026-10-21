package autodotes_policy.validators

import rego.v1

# -----------------------------------------------------------------------------
# Shared generic format validators
#
# Generic string/URL/HTML format checks usable by any policy in this
# package — not tied to any one job template. Policy-domain-specific checks
# (e.g. RITM traceability) belong in their own `*_validators.rego` file
# instead (see ritm_validators.rego).
#
# This file lives in the `autodotes_policy.validators` sub-namespace and is
# only imported by policies that actually use it:
#
#   import data.autodotes_policy.validators
#
#   some_policy_violations contains msg if {
#       addr := object.get(input_extra_vars, "email", "")
#       not validators.valid_email(addr)
#       msg := $"📧 '{addr}' is not a valid email address."
#   }
# -----------------------------------------------------------------------------

# Patterns that make HTML unsafe to render (XSS vectors). Plain text with no
# tags at all, or text with harmless tags (<p>, <b>, <code>, etc.), is fine.
unsafe_html_patterns := [
	`<script`,
	`<iframe`,
	`<object`,
	`<embed`,
	`javascript:`,
	`on[a-zA-Z]+\s*=`,
]

valid_email(email) if {
	regex.match(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`, email)
}

valid_job_link(link) if {
	regex.match(`^https?://`, link)
}

valid_playbook_url(url) if {
	regex.match(`^https://(github\.com|gitlab\.[a-zA-Z0-9.-]+)/`, url)
}

valid_task_path(path) if {
	regex.match(`^.+:[0-9]+$`, path)
}

contains_unsafe_html(text) if {
	some pattern in unsafe_html_patterns
	regex.match(pattern, text)
}
