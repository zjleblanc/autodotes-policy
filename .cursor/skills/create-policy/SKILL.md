---
name: create-policy
description: >-
  Scaffold a new OPA policy (rego file, test file, test payload JSON) in this
  repo's policies/ tree, following the established autodotes_policy
  conventions. Use when the user asks to add, create, or write a new policy,
  job template policy, or extra_vars validation rule.
---

# Create Policy

Scaffolds a new OPA policy end-to-end: the `.rego` rule file, its
`_test.rego` companion, and a test payload JSON — all matching this repo's
existing style.

## Step 1: Pick the target package

Discover existing packages and ask the user to choose one before writing
anything.

1. List directories directly under `policies/` (each is an independent OPA
   bundle).
2. For each directory, find its Rego package name:
   `rg '^package ' policies/<dir>/*.rego --glob '!*_test.rego'`
3. Exclude any package/directory whose name ends in `_test` — test packages
   are auto-created alongside their parent package, never a target on their
   own.
4. Use `AskQuestion` to ask which package the new policy belongs to, listing
   the discovered packages plus a `Create new package` option.
   - If the user picks "Create new package", ask for the new package name
     (lowercase, `snake_case`).

## Step 2: Gather policy requirements

If not already clear from the user's request, confirm:
- The policy name (lowercase `snake_case`, e.g. `job_failure_notification`).
- The `extra_vars` fields it validates and the rule for each (required,
  format/regex, allowed set, numeric range, etc.).

## Step 3: Scaffold a new package (only if created in Step 1)

1. Create the directory `policies/<package>/`, plus its `validators/` and
   `tests/` subdirectories (`policies/<package>/validators/`,
   `policies/<package>/tests/`).
2. Add `policies/<package>/.manifest`:
   ```json
   {
     "roots": ["<package>"]
   }
   ```
   (Required per [policy-bundle-manifest.mdc](../rules/policy-bundle-manifest.mdc) — every subdirectory under `policies/` must scope its bundle roots or `opa build` defaults to claiming the entire data document. `"roots": ["<package>"]` also covers the `<package>.validators` sub-namespace, so no separate manifest entry is needed for it.)
3. Create `tests/data/<package>/payloads/` (the top-level repo `tests/`
   directory that holds example payload JSON — distinct from the
   `policies/<package>/tests/` directory created in step 1, which holds
   `_test.rego` logic).

## Step 4: Check for reusable validators first

Per [policy-validator-functions.mdc](../rules/policy-validator-functions.mdc),
validator functions and shared config (regex patterns, `valid_*`/`contains_*`
predicates, allowed-value sets) must live in dedicated
`policies/<package>/validators/*_validators.rego` files, under a
`<package>.validators` sub-namespace — never inline in a policy's own
`<name>.rego`.

1. List existing validator files: `ls policies/<package>/validators/*_validators.rego`.
2. For each check the new policy needs, see if an existing validator file's
   scope already fits (e.g. a URL/email/HTML format check belongs in a
   generic `format_validators.rego`; a RITM traceability check belongs in
   `ritm_validators.rego`). Add the new validator there.
3. Only create a new `<scope>_validators.rego` file when no existing file's
   scope fits. Name it after what it validates, not after the policy that
   first needed it. It must declare `package <package>.validators`.
4. If the new policy ends up using any validator, it must
   `import data.<package>.validators` and reference the function/rule with
   the `validators.` prefix (e.g. `validators.ritm_violations`). Only add
   this import to policy files that actually call into `validators` —
   skip it entirely if the new policy's checks are self-contained.
5. `input_extra_vars` is not a validator — it's a local one-liner
   (`input_extra_vars := object.get(input, "extra_vars", {})`) that each
   policy file defines for itself. Check whether the new policy needs it,
   and if so add it directly in Step 5's policy file rather than pulling it
   in via `validators`.

## Step 5: Write the policy file

Create `policies/<package>/<policy_name>.rego`. It should contain only the
`<policy_name>_violations` rules and the `<policy_name>` entrypoint decision
rule — no validator function definitions (those went in Step 4).

```rego
package <package>

import rego.v1
# Only add this import if Step 4 found a validator this policy actually uses:
import data.<package>.validators

# =============================================================================
# <POLICY TITLE> POLICY
# =============================================================================
# Validates <what/why> by:
# 1. <rule 1 summary>
# 2. <rule 2 summary>
#
# Input structure expected:
# {
#   "extra_vars": {
#     "<field>": "<example>"
#   }
# }
# =============================================================================

# Extract extra_vars from input with safe fallback to empty object
input_extra_vars := object.get(input, "extra_vars", {})

# -----------------------------------------------------------------------------
# VALIDATION RULES
# -----------------------------------------------------------------------------

<policy_name>_violations contains msg if {
	val := object.get(input_extra_vars, "<field>", "")
	val == ""
	msg := "<emoji> <field> is missing."
}

# If this policy folds in a shared validator's checks, reference it with the
# `validators.` prefix, e.g.:
#
# <policy_name>_violations contains msg if {
# 	some msg in validators.ritm_violations
# }

# -----------------------------------------------------------------------------
# POLICY DECISION
# -----------------------------------------------------------------------------

# METADATA
# description: <short description, keep the whole comment line under ~120 chars>
# entrypoint: true
default <policy_name> := {
	"allowed": true,
	"violations": [],
}

<policy_name> := result if {
	count(<policy_name>_violations) > 0
	result := {
		"allowed": false,
		"violations": <policy_name>_violations,
	}
}
```

Rules of this codebase's style:
- One violation rule block per check; OR multiple `contains` blocks with the
  same head to accumulate independent violations (see
  [restart_service.rego](../../policies/autodotes_policy/restart_service.rego)).
- Build messages with `$"...{var}..."` string interpolation, not `sprintf`,
  unless the expression truly needs `sprintf`'s formatting — `regal lint`
  flags `sprintf` with the `prefer-string-interpolation` rule.
- House style uses a short emoji + a dry, memo-toned violation message (see
  existing policies for tone), but this is cosmetic — functional correctness
  matters more than jokes.

## Step 6: Write the test file

Create `policies/<package>/tests/<policy_name>_test.rego` (test logic lives
in the package's `tests/` subdirectory; it still declares `package
<package>_test`, since package names are independent of file location):

```rego
package <package>_test

import rego.v1

import data.<package>

# -----------------------------------------------------------------------------
# Unit tests for <policy_name>.rego
#
# Example payloads: tests/data/<package>/payloads/<policy_name>.json
# (loaded as data.<package>.payloads.<policy_name>.* when running `opa test`,
# referenced below via the `<package>` import)
# -----------------------------------------------------------------------------

test_<policy_name>_allows_valid if {
	payload := <package>.payloads.<policy_name>.valid
	result := <package>.<policy_name> with input as payload
	result.allowed == true
	count(result.violations) == 0
}

test_<policy_name>_denies_<scenario> if {
	payload := <package>.payloads.<policy_name>.<scenario>
	result := <package>.<policy_name> with input as payload
	result.allowed == false
	count(result.violations) > 0
}
```

Include one `allows_valid` test plus one `denies_<scenario>` test per
violation rule written in Step 5.

## Step 7: Write the test payload JSON

Create `tests/data/<package>/payloads/<policy_name>.json`. Look at an
existing payload file (e.g.
[tf_web_deploy.json](../../tests/data/autodotes_policy/payloads/tf_web_deploy.json)
for a minimal example, or
[disk_expansion.json](../../tests/data/autodotes_policy/payloads/disk_expansion.json)
for one with several scenarios) and copy its envelope shape — `id`, `name`,
`created`, `created_by`, `credentials`, `execution_environment`,
`extra_vars`, `inventory`, `job_template`, `launched_by`, `organization`,
`playbook`, `project`, etc. Only `extra_vars` is actually read by the policy;
the rest just keeps the fixture realistic and consistent with the others.

Structure:
```json
{
  "<policy_name>": {
    "valid": { "...envelope...": "...", "extra_vars": { } },
    "<scenario>": { "...envelope...": "...", "extra_vars": { } }
  }
}
```

Scenario keys must exactly match the `<scenario>` names referenced in the
test file from Step 6.

## Step 8: Verify

Run, in order, and fix any failures before finishing:

```bash
opa check --strict policies/
regal lint policies/
opa test policies/ tests/data/ -v
```

Common lint fixes:
- `prefer-string-interpolation` → switch `sprintf("...%v...", [x])` to
  `$"...{x}..."`.
- `line-length` → shorten the `# description:` METADATA comment.

## Step 9: Report, don't commit

Summarize the files created and test results. Do not run `git commit` or
`git push` — leave that to the user.
