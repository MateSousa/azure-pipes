#!/usr/bin/env bash
# REG_TOKEN, ORG, RUNNER_LABELS injected per-task via ECS containerOverrides.
set -euo pipefail

: "${REG_TOKEN:?REG_TOKEN env var is required (set by dispatcher)}"
: "${ORG:?ORG env var is required (set by dispatcher)}"
: "${RUNNER_LABELS:=fargate}"

./config.sh \
  --url "https://github.com/${ORG}" \
  --token "${REG_TOKEN}" \
  --name "fargate-$(hostname)-$$" \
  --labels "${RUNNER_LABELS}" \
  --ephemeral \
  --unattended \
  --disableupdate \
  --replace

exec ./run.sh
