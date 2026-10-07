package autodotes_policy

import rego.v1

# METADATA
# description: Default-deny catch-all that blocks job execution.
# entrypoint: true
deny := {
	"allowed": false,
	"violations": ["No job execution is allowed 🙅"],
}
