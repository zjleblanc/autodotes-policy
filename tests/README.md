# Testing

This directory holds **example payloads** used by the OPA unit tests that live
alongside each policy under [`policies/autodotes_policy/`](../policies/autodotes_policy/).

- Test *logic* (`*_test.rego`) stays next to the policy it tests, following
  [OPA's own convention](https://www.openpolicyagent.org/docs/latest/policy-testing/).
- Test *data* (example payloads) lives here, under `tests/data/`, so it never
  gets packaged into a production bundle by `opa build`.

## Directory layout

```
tests/
├── README.md                                   # you are here
└── data/
    └── autodotes_policy/
        └── payloads/
            ├── deny.json                        # payloads for deny.rego
            ├── demo_database_maintenance.json   # payloads for demo_database_maintenance.rego
            └── tf_web_deploy.json                # payloads for tf_web_deploy.rego
```

Each JSON file is a map of **scenario name → full AAP policy-enforcement
payload**. Every payload follows the real input schema Ansible Automation
Platform (AAP) sends to OPA at policy-enforcement time — see the
[Ansible Automation Platform integration section](../README.md#ansible-automation-platform)
in the main README for a summary, and the
[official Red Hat docs](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/integrate-ref_pac_inputs_outputs)
for the full reference. Using full-shape payloads (not minimal stubs) keeps
the tests honest about what a policy will actually see in production.

For example, `tests/data/autodotes_policy/payloads/tf_web_deploy.json` looks like:

```json
{
  "tf_web_deploy": {
    "valid": { "...full AAP payload...": "with extra_vars.az_web_vm_size = Standard_DS1_v2" },
    "invalid_key": { "...": "extra_vars includes a disallowed key" },
    "invalid_value": { "...": "extra_vars.az_web_vm_size is not an allowed size" }
  }
}
```

## How OPA loads this data

`opa test` (and `opa eval`) can take multiple root directories. When you run:

```sh
opa test policies/ tests/data/ -v
```

OPA loads:
- All `.rego` files under `policies/` (policies **and** their `_test.rego` files)
- All `.json` files under `tests/data/` as plain data

Because the payloads live at `tests/data/autodotes_policy/payloads/*.json`,
they are addressable in Rego as:

```rego
data.autodotes_policy.payloads.<policy_name>.<scenario_name>
```

For example: `data.autodotes_policy.payloads.tf_web_deploy.valid`.

## Running tests locally

Run the full suite (all policies, all payloads) from the repo root:

```sh
opa test policies/ tests/data/ -v
```

`-v` prints each test name individually, which is useful in CI logs and when
debugging a failure. Drop it for a terse pass/fail summary.

### Running tests for a single policy

`opa test` doesn't filter by package out of the box, but you can use the
`--run` flag with a regex that matches test names:

```sh
opa test policies/ tests/data/ -v --run 'tf_web_deploy'
```

### Requirements

You need the [`opa`](https://www.openpolicyagent.org/docs/latest/#running-opa)
CLI on your `PATH`. No other tooling is required to run tests locally.

## Contributing new tests

1. **Add (or extend) an example payload.** Open the JSON file for the policy
   you're changing under `tests/data/autodotes_policy/payloads/` (or create a
   new one, named after the policy, if it doesn't exist yet). Add a new
   top-level scenario key with a full AAP-shaped payload, tailoring
   `extra_vars` to exercise the behavior you want to test.

2. **Write the assertion.** In the matching `policies/autodotes_policy/<policy>_test.rego`
   file, add a `test_<description>` rule. Each test package follows the
   `_test` suffix convention expected by Regal and the wider Rego community:

   ```rego
   package autodotes_policy_test

   import rego.v1

   import data.autodotes_policy

   test_tf_web_deploy_denies_disallowed_key if {
       payload := autodotes_policy.payloads.tf_web_deploy.invalid_key
       result := autodotes_policy.tf_web_deploy with input as payload
       result.allowed == false
       count(result.violations) > 0
   }
   ```

3. **Run the suite locally** (see above) and confirm your new test passes
   and the rest of the suite is unaffected.

4. **Lint before pushing.** `regal lint policies/` and `opa fmt --fail --list policies/`
   both run in CI and pre-commit — run them locally to catch issues early:

   ```sh
   opa fmt --fail --list policies/
   regal lint policies/
   ```

5. **Open a pull request.** Briefly describe the new scenario and why it
   matters (e.g. "adds coverage for a staging target with a malformed change
   ticket").

## CI and pre-commit integration

- **CI**: the [`Build and Publish OPA Bundle`](../.github/workflows/bundle.yaml)
  workflow runs `opa test policies/ tests/data/ -v` after linting and before
  building bundles. A failing test blocks the bundle build.
- **Pre-commit**: the `opa-test` hook in
  [`.pre-commit-config.yaml`](../.pre-commit-config.yaml) runs the same
  command locally on every `git commit` that touches `.rego` files or
  anything under `tests/data/`. Install it once per clone with:

  ```sh
  pip install pre-commit
  pre-commit install
  ```

Either way, `_test.rego` files and everything under `tests/data/` are
excluded from production bundles — `opa build` is invoked with
`--ignore '*_test.rego'`, and `tests/data/` lives outside `policies/` so it's
never part of the build input in the first place.
