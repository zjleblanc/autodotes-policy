package autodotes_policy

import rego.v1

deny := { 
	"allowed": false,
	"violations": ["No job execution is allowed 🙅"]
}
