package autodotes_policy_test

import rego.v1

import data.autodotes_policy

# -----------------------------------------------------------------------------
# Unit tests for job_failure_notification.rego
#
# Example payloads: tests/data/autodotes_policy/payloads/job_failure_notification.json
# (loaded as data.autodotes_policy.payloads.job_failure_notification.* when
# running `opa test`, referenced below via the `autodotes_policy` import)
# -----------------------------------------------------------------------------

test_job_failure_notification_allows_valid if {
	payload := autodotes_policy.payloads.job_failure_notification.valid
	result := autodotes_policy.job_failure_notification with input as payload
	result.allowed == true
	count(result.violations) == 0
}

test_job_failure_notification_allows_valid_html if {
	payload := autodotes_policy.payloads.job_failure_notification.valid_html
	result := autodotes_policy.job_failure_notification with input as payload
	result.allowed == true
	count(result.violations) == 0
}

test_job_failure_notification_denies_bad_job_link if {
	payload := autodotes_policy.payloads.job_failure_notification.bad_job_link
	result := autodotes_policy.job_failure_notification with input as payload
	result.allowed == false
	count(result.violations) > 0
}

test_job_failure_notification_denies_bad_email if {
	payload := autodotes_policy.payloads.job_failure_notification.bad_email
	result := autodotes_policy.job_failure_notification with input as payload
	result.allowed == false
	count(result.violations) > 0
}

test_job_failure_notification_denies_empty_recipients if {
	payload := autodotes_policy.payloads.job_failure_notification.empty_recipients
	result := autodotes_policy.job_failure_notification with input as payload
	result.allowed == false
	count(result.violations) > 0
}

test_job_failure_notification_denies_bad_playbook_url if {
	payload := autodotes_policy.payloads.job_failure_notification.bad_playbook_url
	result := autodotes_policy.job_failure_notification with input as payload
	result.allowed == false
	count(result.violations) > 0
}

test_job_failure_notification_denies_bad_task_path if {
	payload := autodotes_policy.payloads.job_failure_notification.bad_task_path
	result := autodotes_policy.job_failure_notification with input as payload
	result.allowed == false
	count(result.violations) > 0
}

test_job_failure_notification_denies_unsafe_html if {
	payload := autodotes_policy.payloads.job_failure_notification.unsafe_html
	result := autodotes_policy.job_failure_notification with input as payload
	result.allowed == false
	count(result.violations) > 0
}
