"""
ConnectPoc-EcsScheduler Lambda Function

Iterates over a list of virtual agents (from AGENTS_CONFIG env var),
checks if each agent's ECS task is already running via ListTasks,
and starts new tasks for agents that aren't running.

All decisions are logged with structured JSON for CloudWatch audit.
"""

import os
import json
import logging
from datetime import datetime, timezone

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ecs_client = boto3.client("ecs")


def _log(action, **kwargs):
    """Emit a structured JSON log line for CloudWatch Logs Insights queries."""
    entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "action": action,
        **kwargs,
    }
    logger.info(json.dumps(entry))


def _is_task_running(cluster_arn, agent_id):
    """Check if an ECS task started by this agent_id is currently running.

    Returns the task ARN if running, None otherwise.
    """
    response = ecs_client.list_tasks(
        cluster=cluster_arn,
        startedBy=agent_id,
        desiredStatus="RUNNING",
    )

    task_arns = response.get("taskArns", [])
    if not task_arns:
        return None

    # Verify the task is actually in a running state
    describe = ecs_client.describe_tasks(cluster=cluster_arn, tasks=task_arns)
    for task in describe.get("tasks", []):
        status = task.get("lastStatus")
        if status in ("RUNNING", "PENDING", "PROVISIONING"):
            return task["taskArn"]

    return None


def _start_task(cluster_arn, task_definition_arn, agent, container_name,
                subnet_ids, security_group_ids):
    """Start an ECS Fargate task for the given agent with container overrides."""
    # Build environment overrides: always include AGENT_ID, plus any agent-specific vars
    env_overrides = [{"name": "AGENT_ID", "value": agent["agent_id"]}]
    for key, value in agent.get("environment", {}).items():
        if isinstance(value, bool):
            env_overrides.append({"name": key, "value": str(value).lower()})
        else:
            env_overrides.append({"name": key, "value": str(value)})

    response = ecs_client.run_task(
        cluster=cluster_arn,
        taskDefinition=task_definition_arn,
        launchType="FARGATE",
        count=1,
        startedBy=agent["agent_id"],
        networkConfiguration={
            "awsvpcConfiguration": {
                "subnets": subnet_ids,
                "securityGroups": security_group_ids,
                "assignPublicIp": "ENABLED",
            }
        },
        overrides={
            "containerOverrides": [
                {
                    "name": container_name,
                    "environment": env_overrides,
                }
            ],
        },
    )

    if response.get("failures"):
        raise RuntimeError(
            f"ECS RunTask failed for {agent['agent_id']}: "
            f"{json.dumps(response['failures'])}"
        )

    return response["tasks"][0]["taskArn"]


def handler(event, context):
    cluster_arn = os.environ["ECS_CLUSTER_ARN"]
    task_definition_arn = os.environ["TASK_DEFINITION_ARN"]
    container_name = os.environ["CONTAINER_NAME"]
    agents_config = json.loads(os.environ["AGENTS_CONFIG"])
    subnet_ids = [s for s in os.environ.get("SUBNET_IDS", "").split(",") if s]
    security_group_ids = [s for s in os.environ.get("SECURITY_GROUP_ID", os.environ.get("SECURITY_GROUP_IDS", "")).split(",") if s]

    _log("AGENT_SCAN_START", total_agents=len(agents_config))

    started = 0
    skipped = 0
    failed = 0

    for agent in agents_config:
        agent_id = agent["agent_id"]
        agent_name = agent.get("agent_name", agent_id)

        try:
            running_arn = _is_task_running(cluster_arn, agent_id)

            if running_arn:
                _log(
                    "AGENT_TASK_RUNNING",
                    agent_id=agent_id,
                    agent_name=agent_name,
                    existing_task_arn=running_arn,
                )
                skipped += 1
                continue

            _log("AGENT_TASK_STARTING", agent_id=agent_id, agent_name=agent_name)

            new_task_arn = _start_task(
                cluster_arn=cluster_arn,
                task_definition_arn=task_definition_arn,
                agent=agent,
                container_name=container_name,
                subnet_ids=subnet_ids,
                security_group_ids=security_group_ids,
            )

            _log(
                "AGENT_TASK_STARTED",
                agent_id=agent_id,
                agent_name=agent_name,
                task_arn=new_task_arn,
            )
            started += 1

        except Exception as e:
            _log(
                "AGENT_TASK_FAILED",
                agent_id=agent_id,
                agent_name=agent_name,
                error=str(e),
            )
            failed += 1

    _log(
        "AGENT_SCAN_COMPLETE",
        total=len(agents_config),
        started=started,
        skipped=skipped,
        failed=failed,
    )

    return {
        "statusCode": 200,
        "body": json.dumps({
            "total": len(agents_config),
            "started": started,
            "skipped": skipped,
            "failed": failed,
        }),
    }
