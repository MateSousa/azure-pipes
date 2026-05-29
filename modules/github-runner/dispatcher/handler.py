"""GitHub webhook → ECS RunTask dispatcher.

Triggered by GitHub `workflow_job` events. On `action == "queued"` and a matching
runner label, mints a fresh org-scoped runner registration token via the GitHub
App and launches a single ephemeral Fargate task that will register, run the
job, and exit.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import logging
import os
import time

import boto3
import jwt
import requests

log = logging.getLogger()
log.setLevel(logging.INFO)

_sm = boto3.client("secretsmanager")
_ecs = boto3.client("ecs")

CLUSTER_ARN     = os.environ["CLUSTER_ARN"]
TASK_DEFINITION = os.environ["TASK_DEFINITION"]
CONTAINER_NAME  = os.environ["CONTAINER_NAME"]
SUBNETS         = [s for s in os.environ["SUBNETS"].split(",") if s]
SECURITY_GROUPS = [s for s in os.environ["SECURITY_GROUPS"].split(",") if s]
ASSIGN_PUBLIC_IP = os.environ.get("ASSIGN_PUBLIC_IP", "DISABLED")
RUNNER_LABEL    = os.environ["RUNNER_LABEL"]

APP_ID_ARN          = os.environ["APP_ID_SECRET_ARN"]
APP_PRIVATE_KEY_ARN = os.environ["APP_PRIVATE_KEY_SECRET_ARN"]
WEBHOOK_SECRET_ARN  = os.environ["WEBHOOK_SECRET_ARN"]
ORG_SECRET_ARN      = os.environ["ORG_SECRET_ARN"]

_secret_cache: dict[str, str] = {}


def _secret(arn: str) -> str:
    if arn not in _secret_cache:
        _secret_cache[arn] = _sm.get_secret_value(SecretId=arn)["SecretString"]
    return _secret_cache[arn]


def _verify_signature(body: bytes, signature: str | None) -> None:
    if not signature:
        raise PermissionError("missing X-Hub-Signature-256 header")
    mac = hmac.new(_secret(WEBHOOK_SECRET_ARN).encode(), body, hashlib.sha256).hexdigest()
    if not hmac.compare_digest(f"sha256={mac}", signature):
        raise PermissionError("invalid webhook signature")


def _installation_token() -> tuple[str, str]:
    """Exchange the GitHub App private key for an installation access token."""
    org = _secret(ORG_SECRET_ARN)
    app_id = _secret(APP_ID_ARN)
    pem = _secret(APP_PRIVATE_KEY_ARN)

    now = int(time.time())
    app_jwt = jwt.encode(
        {"iat": now - 60, "exp": now + 540, "iss": app_id},
        pem,
        algorithm="RS256",
    )
    headers = {
        "Authorization": f"Bearer {app_jwt}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    r = requests.get(f"https://api.github.com/orgs/{org}/installation", headers=headers, timeout=10)
    r.raise_for_status()
    tokens_url = r.json()["access_tokens_url"]

    r = requests.post(tokens_url, headers=headers, timeout=10)
    r.raise_for_status()
    return org, r.json()["token"]


def _registration_token(org: str, installation_token: str) -> str:
    r = requests.post(
        f"https://api.github.com/orgs/{org}/actions/runners/registration-token",
        headers={
            "Authorization": f"Bearer {installation_token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        },
        timeout=10,
    )
    r.raise_for_status()
    return r.json()["token"]


def _run_task(reg_token: str, org: str) -> str:
    resp = _ecs.run_task(
        cluster=CLUSTER_ARN,
        taskDefinition=TASK_DEFINITION,
        launchType="FARGATE",
        count=1,
        networkConfiguration={
            "awsvpcConfiguration": {
                "subnets": SUBNETS,
                "securityGroups": SECURITY_GROUPS,
                "assignPublicIp": ASSIGN_PUBLIC_IP,
            }
        },
        overrides={
            "containerOverrides": [
                {
                    "name": CONTAINER_NAME,
                    "environment": [
                        {"name": "REG_TOKEN", "value": reg_token},
                        {"name": "ORG", "value": org},
                        {"name": "RUNNER_LABELS", "value": RUNNER_LABEL},
                    ],
                }
            ]
        },
        propagateTags="TASK_DEFINITION",
    )
    failures = resp.get("failures", [])
    if failures:
        raise RuntimeError(f"ecs:RunTask failed: {failures}")
    return resp["tasks"][0]["taskArn"]


def handler(event, _context):
    headers = {k.lower(): v for k, v in (event.get("headers") or {}).items()}
    body_raw = event.get("body") or ""
    if event.get("isBase64Encoded"):
        body_raw = base64.b64decode(body_raw)
    else:
        body_raw = body_raw.encode()

    try:
        _verify_signature(body_raw, headers.get("x-hub-signature-256"))
    except PermissionError as exc:
        log.warning("rejected webhook: %s", exc)
        return {"statusCode": 401, "body": "unauthorized"}

    if headers.get("x-github-event") == "ping":
        return {"statusCode": 200, "body": "pong"}

    if headers.get("x-github-event") != "workflow_job":
        return {"statusCode": 204, "body": ""}

    payload = json.loads(body_raw)
    if payload.get("action") != "queued":
        return {"statusCode": 204, "body": ""}

    labels = payload.get("workflow_job", {}).get("labels", []) or []
    if RUNNER_LABEL not in labels:
        log.info("skip: job labels %s do not include %s", labels, RUNNER_LABEL)
        return {"statusCode": 204, "body": ""}

    org, inst_token = _installation_token()
    reg_token = _registration_token(org, inst_token)
    task_arn = _run_task(reg_token, org)

    log.info("launched runner task %s for job %s", task_arn, payload.get("workflow_job", {}).get("id"))
    return {"statusCode": 202, "body": json.dumps({"task_arn": task_arn})}
