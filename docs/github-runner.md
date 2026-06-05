# Self-hosted GitHub Actions runners on AWS Fargate

## What this is

An on-demand pool of GitHub Actions runners that live inside our AWS account
instead of on GitHub-hosted infrastructure. Each runner is a fresh, single-use
Fargate task — it starts when a job is queued, registers itself with GitHub,
runs exactly one job, deregisters, and exits. There is no idle capacity, no
persistent runner pool, no shared filesystem between jobs.

## Where it runs

```
GitHub workflow_job webhook ──► API Gateway (HTTP) ──► Lambda dispatcher
                                                              │
                                                              │ ecs:RunTask
                                                              ▼
                                                  Fargate task in our VPC
                                                  (private subnets, egress
                                                   via NAT to api.github.com)
                                                              │
                                                              ▼
                                            registers as runner, runs job,
                                            exits  →  task disappears
```

- **API Gateway HTTP API** receives the webhook from a GitHub
  *organization-level webhook* subscribed to the `workflow_job` event.
- **Dispatcher Lambda** verifies the webhook HMAC, mints a short-lived runner
  registration token from a GitHub App (credentials in AWS Secrets Manager),
  and launches one Fargate task per `queued` event.
- **ECS Fargate task** runs the GitHub Actions runner binary in `--ephemeral`
  mode in the cluster, in private subnets, behind a SG that allows only HTTPS
  egress. The task's CloudWatch log group is `/ecs/<project>-github-runner`.

## The dispatcher Lambda

The dispatcher is a Python Lambda packaged as a **container image** (so its
Python dependencies — `PyJWT`, `cryptography`, `requests` — ship with the
function instead of as layers). It is the single point of contact between
GitHub and our ECS cluster.

**Responsibilities, in order, for every incoming POST:**

1. **Verify the GitHub webhook signature.** Computes
   `HMAC-SHA256(body, webhook_secret)` and compares against the
   `X-Hub-Signature-256` header. Mismatch → returns `401`.
   The webhook secret is read from AWS Secrets Manager
   (`<project>/github-runner/webhook-secret`).
2. **Short-circuit on irrelevant events.** Replies `200 pong` to the GitHub
   `ping` event, returns `204 No Content` for anything that isn't
   `workflow_job` or whose `action` isn't `queued`, and for jobs whose
   `labels` don't include the runner's label (default `fargate`).
3. **Mint a fresh GitHub App installation token.** Builds a 10-minute JWT
   signed with the GitHub App private key (from Secrets Manager), calls
   `GET /orgs/{org}/installation` to find the org's installation, then
   `POST .../access_tokens` to get an installation token.
4. **Mint a one-time runner registration token.** Calls
   `POST /orgs/{org}/actions/runners/registration-token` with the
   installation token. The returned token is valid for ~1 hour and is
   single-use against the registration endpoint.
5. **Launch the Fargate task.** Calls `ecs:RunTask` against the existing
   cluster, with the runner task definition. The registration token, the
   org slug, and the runner label are injected per-invocation via
   `containerOverrides.environment` — they are never baked into the task
   definition, never written to logs, and never persisted.

**Environment variables (configured by Terraform):**

| Var | Purpose |
|---|---|
| `CLUSTER_ARN` | Cluster to `RunTask` against. |
| `TASK_DEFINITION` | Family name of the runner task def. |
| `CONTAINER_NAME` | Name of the container override target. |
| `SUBNETS` / `SECURITY_GROUPS` | Network config for the launched task. |
| `ASSIGN_PUBLIC_IP` | `DISABLED` by default — egress via NAT. |
| `RUNNER_LABEL` | Label the dispatcher cares about and injects. |
| `APP_ID_SECRET_ARN`, `APP_PRIVATE_KEY_SECRET_ARN`, `WEBHOOK_SECRET_ARN`, `ORG_SECRET_ARN` | Secrets Manager ARNs read at runtime. |

**IAM:** the dispatcher's role is scoped to exactly what it needs and nothing
more: `secretsmanager:GetSecretValue` on the four ARNs above,
`ecs:RunTask` on the runner task definition (with a condition pinning the
cluster), `iam:PassRole` on the runner execution + task roles (with a
`PassedToService = ecs-tasks.amazonaws.com` condition), and CloudWatch Logs
on its own log group.

**Idempotency / failure modes:**

- If `RunTask` fails (e.g. quota, networking misconfig), the response body
  contains the `failures` list and Lambda returns 5xx; GitHub will retry the
  delivery a few times on its own.
- Secrets are cached for the lifetime of a warm Lambda container. Rotating
  the values requires a Lambda config update (or new image deploy) to flush
  cached containers, **or** wait for them to idle out (~15 min).
- The dispatcher never holds the registration token after `RunTask` returns —
  the token lives only on the task it was injected into.

## The runner container image

The runner image is an Ubuntu-based container that bundles the official
`actions/runner` binary and a thin entrypoint script. Built once, pushed to
ECR, and consumed by every task that the dispatcher launches.

**Dockerfile shape:**

- Base: `public.ecr.aws/ubuntu/ubuntu:22.04` (`libicu70` is required by the
  runner's .NET dependency).
- Installs `curl`, `git`, `jq`, `sudo`, `unzip` and the runner's runtime
  deps; everything else (Node, Python, etc.) is provided by the workflow's
  `setup-*` actions on demand.
- Downloads `actions-runner-linux-${arch}-${version}.tar.gz` from the
  `actions/runner` GitHub releases. `RUNNER_VERSION` is an optional build
  arg — left empty, the build queries the GitHub API for the **latest**
  release tag and installs that. (This is important: GitHub server-side
  refuses to dispatch jobs to runners more than ~6 months old; pinning leads
  to silent "Forbidden – deprecated" failures down the road.)
- Runs as a non-root `runner` user (the runner refuses to start as root).
- Copies `entrypoint.sh` with `--chmod=0755` so the executable bit is set
  inside the image regardless of how the source file is checked out.

**Entrypoint contract.** When the dispatcher launches the task, ECS sets
three environment variables via container overrides:

| Var | Source | Used for |
|---|---|---|
| `REG_TOKEN` | minted by the dispatcher for this job | `./config.sh --token` |
| `ORG` | from Secrets Manager (`.../org`) | runner URL `https://github.com/<ORG>` |
| `RUNNER_LABELS` | from the dispatcher (defaults `fargate`) | `./config.sh --labels` |

The script then runs:

```bash
./config.sh \
  --url "https://github.com/${ORG}" \
  --token "${REG_TOKEN}" \
  --name "fargate-$(hostname)-$$" \
  --labels "${RUNNER_LABELS}" \
  --ephemeral --unattended --disableupdate --replace

exec ./run.sh
```

The flags matter:

- `--ephemeral`: the runner deregisters and exits after **one** job. This
  is what makes per-job isolation real.
- `--unattended`: don't prompt for anything (we have no TTY).
- `--disableupdate`: don't try to self-update the binary inside the
  container — the version is baked into the image; we redeploy the image
  to upgrade.
- `--replace`: if a stale runner with the same name is still registered
  (rare; mostly happens on rapid retries), overwrite it.

**Lifecycle on each invocation:**

```
ECS RunTask → image pulled (cached after first task in the cluster)
            → entrypoint.sh runs as user `runner`
            → ./config.sh registers with GitHub using REG_TOKEN
            → ./run.sh long-polls GitHub for the queued job
            → job runs, runner writes logs to stdout (→ CloudWatch)
            → ./run.sh exits after the job (because --ephemeral)
            → container exits 0 → task transitions to STOPPED
            → ECS reclaims resources, runner disappears from GitHub
```

**What is *not* in the image:**

- Node, Python, Java, Docker. Workflows install those on demand via the
  standard `setup-*` actions. Keeping the image minimal cuts pull time and
  attack surface.
- AWS CLI v2 (the workflow's task role exposes credentials, but you still
  need the CLI/SDK — install via `setup-` action or a `run` step).

**Updating the image:**

1. Rebuild with `docker build --no-cache` (the `--no-cache` is important
   when relying on the auto-fetch of the latest runner version — otherwise
   Docker reuses the cached layer and never re-queries GitHub).
2. Push to ECR with a new tag.
3. Bump `runner_image_uri` in tfvars and `terraform apply`. That publishes
   a new task definition revision; the next dispatch picks it up.

## How a workflow targets the self-hosted runner

In any repo the GitHub App is installed on, set `runs-on` to the
`fargate` label:

```yaml
# .github/workflows/example.yml
name: example

on:
  push:
    branches: [main]

# Required only if you use OIDC (the `aws-actions/configure-aws-credentials`
# action below). If you use the task role directly, you can omit `permissions`.
permissions:
  id-token: write
  contents: read

jobs:
  build:
    # Both labels must match — `self-hosted` is added automatically by GitHub
    # for any non-hosted runner, and `fargate` is the label the dispatcher
    # registers each runner with.
    runs-on: [self-hosted, fargate]

    # AWS_REGION is not set automatically inside the task; set it here so the
    # AWS SDKs/CLI know which region to use.
    env:
      AWS_REGION: us-east-1

    steps:
      - uses: actions/checkout@v4

      # Option A — use the task role directly (no action needed).
      # The runner container already has AWS credentials from its ECS task
      # role. Any `aws` CLI / SDK call uses that role's permissions.
      - name: Show identity (task role)
        run: aws sts get-caller-identity

      # Option B — assume a more specific role via GitHub OIDC.
      # Use this when different workflows/repos need different roles, or you
      # want narrower permissions than the task role itself.
      - name: Assume per-workflow role
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/example-deploy
          aws-region: us-east-1

      - name: Do the work
        run: |
          aws s3 ls s3://my-bucket
          # ...build, test, deploy, whatever
```

## Notes

- **One task per job.** No state is shared between jobs. If a step writes a
  file, that file is gone the moment the job finishes.
- **AWS identity.** The runner container is the ECS task role
  (`<project>-github-runner-task`). Anything that role can do, the workflow
  can do, with no extra configuration. Grant it only what your workflows need.
- **Cold start.** First task per cluster takes ~30–60s (Fargate provisioning
  + image pull). Subsequent tasks are similar — there is no warm pool.
- **Cost.** Pay for the Fargate task only for the seconds it's running. No
  idle cost.
- **Scaling.** No configuration needed; the dispatcher launches one task per
  queued job, in parallel.
- **Logs.** Runner output is in CloudWatch `/ecs/<project>-github-runner`;
  the dispatcher Lambda's decisions are in
  `/aws/lambda/<project>-github-runner-dispatcher`.
