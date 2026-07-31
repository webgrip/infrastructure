# OpenVEX statements

A scanner tells you a CVE is **present**. It cannot tell you whether it is **exploitable**.
For a CI toolchain image that distinction is most of the finding list: `ci-runner` carries a
Ruby interpreter it never invokes, a Perl runtime pulled in by `git`'s dependency closure, and
three TLS libraries of which one is on an actual code path. A scanner counts all of them.

VEX (Vulnerability Exploitability eXchange) is the machine-readable form of "we looked at it,
here is why it doesn't matter." This directory holds those statements as reviewed, version-controlled
source — not as a scanner flag, not as an allowlist, and deliberately not as something generated.

## Why the statements live here and not in Harbor's CVE allowlist

Harbor has a per-project `cve_allowlist`. It is a list of CVE IDs with no product scope, no
justification, no author, and no expiry. Suppressing `CVE-2025-1234` there suppresses it for
**every image in the project**, forever, with no record of who decided that or why. That is an
allowlist wearing a VEX costume.

An OpenVEX statement is scoped to a **product** (one image at one digest), carries a **status**,
requires a **justification** from a closed vocabulary when you claim `not_affected`, and is signed
into the image's attestation chain. It is reviewable in a PR and auditable after the fact.

The rule: **Harbor's allowlist stays empty.** Every suppression is a statement in this directory.

## Layout

```text
ops/vex/
  README.md                     this file
  statements/
    <image>.openvex.json        per-image statements, hand-authored, reviewed in PR
```

A missing file simply means "no suppressions for this image" — the scan gate treats an absent
VEX document as an empty one, so a new image needs no boilerplate.

## Authoring a statement

Never hand-write the JSON. `vexctl` produces canonical documents and validates the justification
vocabulary, which is the part that is easy to get subtly wrong. Create the statement as its own
document, then **merge** it into the image's file — appending would concatenate two JSON objects
into something no parser accepts:

```bash
vexctl create \
  --product="pkg:oci/ci-runner" \
  --vuln="CVE-2025-12345" \
  --status="not_affected" \
  --justification="vulnerable_code_not_in_execute_path" \
  --author="ryan@webgrip.nl" \
  > /tmp/new-statement.json

# First statement for this image:
mv /tmp/new-statement.json ops/vex/statements/ci-runner.openvex.json

# Subsequent statements:
vexctl merge ops/vex/statements/ci-runner.openvex.json /tmp/new-statement.json \
  > /tmp/merged.json && mv /tmp/merged.json ops/vex/statements/ci-runner.openvex.json
```

The `--product` is the **unversioned** purl. The release pipeline re-stamps it with the digest of
the image actually built (see "How this is applied" below), so a statement written today keeps
applying to tomorrow's rebuild of the same image — and stops applying the moment the component
is removed, because the scanner will no longer report the CVE at all.

Verify before you commit — the gate will reject a document whose `.statements[]` is malformed:

```bash
jq -e 'type=="object" and (.statements|type=="array")' ops/vex/statements/ci-runner.openvex.json
```

### The five `not_affected` justifications

OpenVEX constrains these on purpose. If none of them fits, the honest status is `affected`:

| Justification | Use when |
| --- | --- |
| `component_not_present` | The vulnerable package was never in the image (usually a scanner false positive on a stale advisory). |
| `vulnerable_code_not_present` | The package is present but built without the vulnerable code path (compile flags, stripped module). |
| `vulnerable_code_not_in_execute_path` | The code exists but nothing in this image ever calls it. **The most common honest answer for a CI image.** |
| `vulnerable_code_cannot_be_controlled_by_adversary` | Reachable, but no attacker-controlled input reaches it. |
| `inline_mitigations_already_exist` | Reachable and controllable, but something in the image already blocks exploitation. |

`vulnerable_code_not_in_execute_path` is the workhorse and also the one most often abused. "We
don't think anyone runs it" is not the same claim as "nothing in this image invokes it." Write the
second or write `under_investigation`.

### Statuses other than `not_affected`

- `affected` — real, exploitable, not yet fixed. **This does not suppress anything**; the gate
  still fails. Use it to record that you have triaged a finding and accepted it consciously,
  with an `action_statement` describing the remediation plan.
- `fixed` — remediated in this version. Useful when a scanner's advisory data lags a backported
  distro patch.
- `under_investigation` — triaged, not yet concluded. Suppresses nothing. Prefer this to a
  speculative `not_affected`; it is the status that costs you nothing to be wrong about.

## How this is applied

At release, `.forgejo/actions/cosign-sign-attest` does three things with these files:

1. **Stamps** the built digest into every statement's product ID, so the document describes the
   artifact that actually shipped rather than a floating tag.
2. **Attests** it to the image with `cosign attest --type openvex`, signed by the same OpenBao
   Transit key as the SBOM. The suppression travels with the image and is independently verifiable.
3. **Feeds** it to the scan gate via `grype --vex`, so a justified finding does not fail the build.

Consumers can retrieve it without trusting this repo:

```bash
cosign download attestation --predicate-type=https://openvex.dev/ns \
  harbor.webgrip.dev/webgrip/<image>@sha256:<digest> \
  | jq -r '.payload' | base64 -d | jq '.predicate'
```

## Review discipline

A VEX statement is a security assertion with your name on it. Three rules:

1. **A statement without analysis is a lie with a schema.** If you have not read the advisory and
   traced the call path, the status is `under_investigation`.
2. **Statements are not permanent.** They describe one product at one version. When an image
   changes base or a component moves onto an execute path, the statement is now wrong. The gate
   re-evaluates every release; a stale `not_affected` is worse than no statement at all.
3. **Prefer removing the component.** A suppression is the second-best outcome. `ci-runner` does
   not need a Ruby interpreter; deleting it retires the finding permanently and needs no
   justification from anyone.
