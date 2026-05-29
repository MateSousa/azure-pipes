# ASH — Automated Security Helper

End-to-end guide for using **AWS Automated Security Helper (ASH)** as the security-scanning gate in our CI/CD pipelines (Terraform, Lambda, Frontend).

> Repo: https://github.com/awslabs/automated-security-helper

---

## Table of contents

1. [What ASH is](#1-what-ash-is)
2. [Scanners ASH runs](#2-scanners-ash-runs)
3. [ASH lifecycle in a pipeline](#3-ash-lifecycle-in-a-pipeline)
4. [Reusable workflow](#4-reusable-workflow)
5. [Per-asset usage](#5-per-asset-usage)
6. [Where to check findings](#6-where-to-check-findings)
7. [Suppressions & tuning](#7-suppressions--tuning)
8. [Local runs (dev loop)](#8-local-runs-dev-loop)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. What ASH is

ASH is an AWS-maintained CLI that bundles many open-source security scanners (SAST, IaC, secrets, SBOM, container vulns) into a single command. Instead of wiring up `bandit` + `semgrep` + `checkov` + `cfn-nag` + `detect-secrets` + ... separately, you run `ash scan` and it auto-detects file types, runs the right scanners, and aggregates results into one report.

**Why we use it**

- One install / one command across every pipeline (Terraform, Lambda Python, JS/TS frontend)
- Reproducible (Docker or pipx — same scanners, same versions)
- Emits **SARIF** → integrates with the GitHub Security tab
- Fails the build on HIGH/CRITICAL → real merge gate, not advisory

<placeholder: screenshot of ASH summary output in the Actions log >

---

## 2. Scanners ASH runs

ASH dispatches based on what it finds in the source tree:

| Asset type | Scanners triggered |
|---|---|
| **Secrets** (any file) | `git-secrets`, `detect-secrets` |
| **Python** (Lambda) | `bandit`, `semgrep`, `pip-audit` |
| **JavaScript / TypeScript** (frontend) | `semgrep`, `npm audit` |
| **Terraform** | `checkov`, `tfsec` |
| **CloudFormation** | `cfn-nag`, `checkov` |
| **CDK** | `cdk-nag` |
| **Containers / Dockerfiles** | `checkov`, `grype` (image vulns), `syft` (SBOM) |
| **General SAST** | `semgrep` rulesets |

You don't pick scanners explicitly — ASH auto-detects. The optional `--scanners` flag is only for restricting the set.

<placeholder: screenshot of scanner detection / "Running scanners: ..." line >

---

## 3. ASH lifecycle in a pipeline

```
   ┌──────────┐    ┌──────────────┐    ┌─────────────┐    ┌───────────┐
   │ checkout │ -> │ install ASH  │ -> │ ash scan    │ -> │ SARIF     │
   └──────────┘    └──────────────┘    └─────────────┘    │ + report  │
                                                          └─────┬─────┘
                                                                │
                            ┌───────────────────────────────────┼───────────────────────┐
                            v                                   v                       v
                  ┌──────────────────┐               ┌────────────────────┐    ┌──────────────────┐
                  │ Upload SARIF to  │               │ Upload artifact    │    │ Fail-on-findings │
                  │ GitHub Security  │               │ (raw ASH output)   │    │ gate             │
                  └────────┬─────────┘               └────────────────────┘    └────────┬─────────┘
                           v                                                            v
                  ┌──────────────────┐                                         ┌──────────────────┐
                  │ Code scanning    │                                         │ deploy job runs  │
                  │ alerts in repo   │                                         │ only if ASH ✓    │
                  └──────────────────┘                                         └──────────────────┘
```

**Stages**

1. **Checkout** — standard `actions/checkout@v4`.
2. **Install ASH** — pipx (fast, native) or Docker (no host Python).
3. **Run `ash scan`** — produces `./ash_output/reports/ash.sarif` + a text summary + per-scanner raw outputs.
4. **Publish results** — three sinks in parallel:
   - `upload-sarif` → GitHub Security tab (Code scanning alerts)
   - `upload-artifact` → downloadable raw report on the run page
   - **Fail-on-findings step** → exits non-zero on HIGH/CRITICAL, blocking merge / blocking the deploy job
5. **Deploy job** runs only if scan job is green (`needs: scan`).

<placeholder: screenshot of full GitHub Actions run graph showing scan -> deploy gate >

---

## 4. Reusable workflow

Lives at `workflows/shared/.github/workflows/reusable-security-scan.yml`.

```yaml
name: Security Scan (ASH)

on:
  workflow_call:
    inputs:
      source-dir:
        type: string
        default: "."
      scanners:
        description: "Comma-separated subset (e.g. terraform,python). Empty = auto-detect all."
        type: string
        default: ""
      fail-on-findings:
        type: boolean
        default: true

permissions:
  contents: read
  security-events: write
  actions: read

jobs:
  ash:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with: { python-version: "3.12" }

      - name: Install ASH
        run: pipx install git+https://github.com/awslabs/automated-security-helper.git@v3.0.0

      - name: Run ASH
        env:
          SCANNERS: ${{ inputs.scanners }}
        run: |
          set -e
          SCANNERS_CLEAN="${SCANNERS// /}"
          ARGS=(scan --source-dir "${{ inputs.source-dir }}" \
                --output-dir ./ash_output \
                --output-format sarif)
          if [ -n "$SCANNERS_CLEAN" ]; then
            ARGS+=(--scanners "$SCANNERS_CLEAN")
          fi
          ash "${ARGS[@]}"

      - name: Upload SARIF to GitHub Security
        if: always()
        uses: github/codeql-action/upload-sarif@v4
        with:
          sarif_file: ./ash_output/reports/ash.sarif
          category: ash-${{ inputs.source-dir }}

      - name: Upload raw report artifact
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: ash-report-${{ github.run_id }}
          path: ./ash_output/

      - name: Fail on findings
        if: inputs.fail-on-findings
        run: |
          if grep -q '"level": "error"' ./ash_output/reports/ash.sarif; then
            echo "::error::ASH found HIGH/CRITICAL issues — see Security tab or report artifact."
            exit 1
          fi
```

**Key choices explained**

- `pipx` install of v3 → ~5× faster than the Docker image, deterministic version pin.
- `category: ash-<dir>` → namespaces results so scanning Terraform and Lambda from the same repo doesn't overwrite each other in the Security tab.
- `if: always()` on uploads → we still publish artifacts when the scan fails, so reviewers can see *why*.
- Permissions: `security-events: write` is required for SARIF, `actions: read` is required by `upload-sarif` to fetch workflow-run metadata.

<placeholder: screenshot of the reusable workflow file in GitHub UI >

---

## 5. Per-asset usage

### 5.1 Terraform

```yaml
# .github/workflows/deploy-infra.yml
permissions:
  contents: read
  security-events: write
  actions: read

jobs:
  scan:
    uses: your-org/shared-workflows/.github/workflows/reusable-security-scan.yml@main
    with:
      source-dir: virtual-agent
      scanners: terraform,secrets

  deploy:
    needs: scan
    uses: ./.github/workflows/reusable-deploy-terraform.yml
    with:
      environment: dev
      working-directory: virtual-agent
      # ... other inputs
```

<placeholder: screenshot of Terraform pipeline run with scan step green and deploy step running >

### 5.2 Lambda (Python)

```yaml
jobs:
  scan:
    uses: your-org/shared-workflows/.github/workflows/reusable-security-scan.yml@main
    with:
      source-dir: virtual-agent/lambda
      scanners: python,secrets

  deploy:
    needs: scan
    uses: ./.github/workflows/reusable-deploy-lambda.yml
    with:
      # ... other inputs
```

<placeholder: screenshot of Lambda pipeline showing bandit/semgrep findings list in Actions log >

### 5.3 Frontend (JS / TS)

```yaml
jobs:
  scan:
    uses: your-org/shared-workflows/.github/workflows/reusable-security-scan.yml@main
    with:
      source-dir: frontend
      scanners: nodejs,secrets

  deploy:
    needs: scan
    uses: ./.github/workflows/reusable-deploy-s3.yml
    with:
      # ... other inputs
```

<placeholder: screenshot of frontend pipeline scanning JS/TS files >

---

## 6. Where to check findings

ASH publishes findings to **three** places. Use whichever fits the moment.

### 6.1 GitHub Security tab (primary, for triage)

Navigate to: **`<repo>` → Security → Code scanning**.

- One alert per finding, deduped via SARIF fingerprinting.
- Filter by tool (`bandit`, `checkov`, `semgrep`, ...), severity, branch.
- Click an alert → see the offending file + line + rule description.
- Dismiss with reason: *false positive*, *won't fix*, *used in tests*.
- Alerts auto-close when the next scan no longer reports them.

<placeholder: screenshot of the Code scanning alerts page filtered by tool=checkov >

<placeholder: screenshot of an individual alert showing file/line + rule description >

### 6.2 Actions run page (per-pipeline, for the immediate failure)

Navigate to: **Actions → `<failing run>` → `ash` job → "Run ASH" step**.

You see the ASH text summary — counts per severity per scanner, paths to offending files. This is the fastest read when a PR fails.

<placeholder: screenshot of the "Run ASH" step expanded showing the summary table >

### 6.3 Run artifact (deep dive, raw scanner outputs)

Same Actions run page → bottom of the summary → **Artifacts** → `ash-report-<run_id>`.

Download, unzip — you get the full ASH output:

```
ash_output/
├── reports/
│   ├── ash.sarif               # the SARIF uploaded to Security tab
│   ├── ash_aggregated_results.txt   # human-readable summary
│   └── ash.html                # browsable HTML report
└── work/
    ├── bandit/                 # raw bandit output
    ├── checkov/                # raw checkov output
    ├── semgrep/                # raw semgrep output
    └── ...
```

Use the raw outputs when SARIF doesn't carry enough scanner-specific context (e.g. you need a checkov `BC_*` ID to add a suppression).

<placeholder: screenshot of the Artifacts section on the run page >

<placeholder: screenshot of the ash.html report opened in a browser >

---

## 7. Suppressions & tuning

Always suppress at the **scanner** level — not via ASH CLI flags — so suppressions survive ASH version bumps.

| Scanner | How to suppress | Example |
|---|---|---|
| Checkov | `.checkov.yaml` or inline `# checkov:skip=CKV_AWS_X:reason` | inline above the resource block |
| Bandit | `# nosec B101 - reason` at the line | end-of-line on the offending statement |
| Semgrep | `.semgrepignore` (paths) or `# nosemgrep: rule-id` | inline |
| detect-secrets | `.secrets.baseline` (run `detect-secrets scan > .secrets.baseline` once, commit it) | committed baseline file |
| npm audit | `package.json` `overrides` or `npm audit fix` | resolve the dep |

Repo-wide ASH config: `.ash/config.yaml` at the repo root. Use this for **scanner enable/disable** and **severity thresholds**, not for individual finding suppressions.

```yaml
# .ash/config.yaml — example
scanners:
  bandit: { enabled: true }
  checkov: { enabled: true, soft_fail: false }
  semgrep: { enabled: true }
  cfn-nag: { enabled: false }   # disabled — we don't use CloudFormation

severity_threshold: HIGH   # only HIGH and CRITICAL fail the build
```

<placeholder: screenshot of `.ash/config.yaml` in the repo >

---

## 8. Local runs (dev loop)

Run ASH on your laptop before pushing — same scanners, same results.

### Option A — pipx (matches CI)

```bash
pipx install git+https://github.com/awslabs/automated-security-helper.git@v3.0.0
ash scan --source-dir . --output-dir ./ash_output --output-format text
open ./ash_output/reports/ash.html
```

### Option B — Docker (no Python on host)

```bash
docker run --rm -v "$PWD":/src \
  public.ecr.aws/aws-samples/automated-security-helper:latest \
  scan --source-dir /src --output-dir /src/ash_output
```

Add `ash_output/` to `.gitignore`.

<placeholder: screenshot of a local terminal showing `ash scan` summary output >

---

## 9. Troubleshooting

### `No such command 'secrets'`

`--scanners` was passed with a space after the comma (`terraform, secrets`). Bash split it; `secrets` became a positional arg. **Fix:** strip whitespace, or just omit `--scanners` and let ASH auto-detect.

### `Resource not accessible by integration` on `upload-sarif`

The caller workflow is missing permissions. **Fix:** add to the caller (or workflow level):

```yaml
permissions:
  contents: read
  security-events: write
  actions: read
```

### Code scanning alerts not appearing in the Security tab

- Private repo? Code scanning requires **GitHub Advanced Security** for private repos.
- Workaround: drop the `upload-sarif` step and rely on the artifact + fail-on-findings gate.

<placeholder: screenshot of the GHAS settings page showing Code scanning enabled >

### Scan takes too long

- Cache scanner caches:
  ```yaml
  - uses: actions/cache@v4
    with:
      path: |
        ~/.cache/semgrep
        ~/.cache/pip
      key: ash-${{ runner.os }}-${{ hashFiles('**/requirements*.txt', '**/package-lock.json') }}
  ```
- Pin to ASH v3 native (pipx) instead of the Docker image — Docker image cold-pulls ~1.5 GB.
- Restrict scope with `source-dir` — don't scan the whole monorepo if only one subtree changed.

### A finding is a true false positive

1. Find the rule ID in the artifact's raw scanner output (e.g. `CKV_AWS_50`).
2. Add an inline suppression next to the offending code with a **reason**.
3. Never blanket-disable a rule globally without team review.

<placeholder: screenshot of a dismissed alert with "False positive" reason filled in >

---

## Appendix: severity → exit code mapping

| ASH outcome | SARIF level | Build effect |
|---|---|---|
| CRITICAL | `error` | ❌ fail |
| HIGH | `error` | ❌ fail |
| MEDIUM | `warning` | ✅ pass (visible in alerts) |
| LOW | `note` | ✅ pass |
| INFO | `note` | ✅ pass |

Adjust by editing `severity_threshold` in `.ash/config.yaml` or by changing the `grep` pattern in the *Fail on findings* step.
