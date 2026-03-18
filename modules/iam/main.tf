data "aws_iam_policy_document" "this" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    dynamic "principals" {
      for_each = var.role.assume_role_principals
      content {
        type        = principals.value.type
        identifiers = principals.value.identifiers
      }
    }

    dynamic "condition" {
      for_each = var.role.assume_role_conditions
      content {
        test     = condition.value.test
        variable = condition.value.variable
        values   = condition.value.values
      }
    }
  }
}

resource "aws_iam_role" "this" {
  name                  = "${var.project_name}-${var.role.name}"
  assume_role_policy    = data.aws_iam_policy_document.this.json
  path                  = var.role.path
  description           = var.role.description
  max_session_duration  = var.role.max_session_duration
  force_detach_policies = var.role.force_detach_policies

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.role.name}"
    }
  )
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = toset(var.policies.managed_policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "this" {
  for_each = { for p in var.policies.inline_policies : p.name => p.policy }

  role   = aws_iam_role.this.name
  name   = each.key
  policy = each.value
}
