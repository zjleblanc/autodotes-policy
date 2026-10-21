package autodotes_policy

import data.autodotes_policy.validators
import rego.v1

# =============================================================================
# JOB FAILURE NOTIFICATION POLICY
# =============================================================================
# Validates job-failure notification payloads (as emitted by AAP's failure
# diagnosis/notification job templates) by enforcing:
# 1. job_link starts with a protocol (http/https)
# 2. notification_recipients is a non-empty list of valid email addresses
# 3. playbook_path is provided
# 4. playbook_url points at a GitHub or GitLab host
# 5. root_cause / suggested_fix are valid HTML (plain text is fine; no
#    script/iframe/object/embed tags or inline JS handlers)
# 6. task_path is a file path followed by ":<line number>"
#
# Input structure expected:
# {
#   "extra_vars": {
#     "job_link": "https://ansible.autodotes.com/execution/jobs/playbook/18975/output",
#     "notification_recipients": ["zleblanc@redhat.com"],
#     "playbook_path": "playbooks/jt_failure_random.yml",
#     "playbook_url": "https://github.com/zjleblanc/ansible-eda-demos.git/blob/<sha>/playbooks/jt_failure_random.yml",
#     "root_cause": "...",
#     "suggested_fix": "...",
#     "task_path": "playbooks/tasks/failure_scenarios/snow_stale_incident.yml:2"
#   }
# }
#
# =============================================================================
#
# Format validators (valid_email, valid_job_link, valid_playbook_url,
# valid_task_path, contains_unsafe_html) live in
# validators/format_validators.rego, imported above as `validators`.

# Extract extra_vars from input with safe fallback to empty object
input_extra_vars := object.get(input, "extra_vars", {})

# -----------------------------------------------------------------------------
# VALIDATION RULES
# -----------------------------------------------------------------------------

# job_link: missing or without a protocol
job_failure_notification_violations contains msg if {
	link := object.get(input_extra_vars, "job_link", "")
	not validators.valid_job_link(link)
	msg := $"🔗 job_link '{link}' must start with http:// or https://."
}

# notification_recipients: missing or empty
job_failure_notification_violations contains msg if {
	recipients := object.get(input_extra_vars, "notification_recipients", [])
	count(recipients) == 0
	msg := "📭 notification_recipients is empty. Who exactly is supposed to care about this failure?"
}

# notification_recipients: contains an invalid email address
job_failure_notification_violations contains msg if {
	recipients := object.get(input_extra_vars, "notification_recipients", [])
	some recipient in recipients
	not validators.valid_email(recipient)
	msg := $"📧 '{recipient}' is not a valid email address."
}

# playbook_path: missing
job_failure_notification_violations contains msg if {
	path := object.get(input_extra_vars, "playbook_path", "")
	path == ""
	msg := "📄 playbook_path is missing."
}

# playbook_url: missing or not a GitHub/GitLab link
job_failure_notification_violations contains msg if {
	url := object.get(input_extra_vars, "playbook_url", "")
	not validators.valid_playbook_url(url)
	msg := $"🌐 playbook_url '{url}' must start with a github.com or gitlab host."
}

# root_cause: missing
job_failure_notification_violations contains msg if {
	text := object.get(input_extra_vars, "root_cause", "")
	text == ""
	msg := "🕵️ root_cause is missing. What even happened?"
}

# root_cause: unsafe HTML
job_failure_notification_violations contains msg if {
	text := object.get(input_extra_vars, "root_cause", "")
	text != ""
	validators.contains_unsafe_html(text)
	msg := "🧨 root_cause contains unsafe HTML (script/iframe/object/embed tags or inline JS handlers)."
}

# suggested_fix: missing
job_failure_notification_violations contains msg if {
	text := object.get(input_extra_vars, "suggested_fix", "")
	text == ""
	msg := "🛠️ suggested_fix is missing. Diagnosing without a remedy helps no one."
}

# suggested_fix: unsafe HTML
job_failure_notification_violations contains msg if {
	text := object.get(input_extra_vars, "suggested_fix", "")
	text != ""
	validators.contains_unsafe_html(text)
	msg := "🧨 suggested_fix contains unsafe HTML (script/iframe/object/embed tags or inline JS handlers)."
}

# task_path: missing or not "<file path>:<line number>"
job_failure_notification_violations contains msg if {
	path := object.get(input_extra_vars, "task_path", "")
	not validators.valid_task_path(path)
	msg := $"📍 task_path '{path}' must be a file path followed by ':<line number>' (e.g. tasks/main.yml:12)."
}

# -----------------------------------------------------------------------------
# POLICY DECISION
# -----------------------------------------------------------------------------

# METADATA
# description: Validate job failure notification payloads (link, recipients, URLs, HTML safety, task path).
# entrypoint: true
default job_failure_notification := {
	"allowed": true,
	"violations": [],
}

job_failure_notification := result if {
	count(job_failure_notification_violations) > 0
	result := {
		"allowed": false,
		"violations": job_failure_notification_violations,
	}
}
