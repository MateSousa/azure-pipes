resource "aws_security_group" "this" {
  name        = "${var.project_name}-${var.security_group.name}"
  description = var.security_group.description
  vpc_id      = var.security_group.vpc_id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.security_group.name}"
  })
}

resource "aws_security_group_rule" "ingress" {
  count = length(var.ingress_rules)

  security_group_id = aws_security_group.this.id
  type              = "ingress"
  description       = var.ingress_rules[count.index].description
  from_port         = var.ingress_rules[count.index].from_port
  to_port           = var.ingress_rules[count.index].to_port
  protocol          = var.ingress_rules[count.index].protocol
  cidr_blocks       = var.ingress_rules[count.index].cidr_blocks
  ipv6_cidr_blocks  = var.ingress_rules[count.index].ipv6_cidr_blocks
  self              = var.ingress_rules[count.index].self

  source_security_group_id = length(var.ingress_rules[count.index].security_groups) > 0 ? var.ingress_rules[count.index].security_groups[0] : null
}

resource "aws_security_group_rule" "egress" {
  count = length(var.egress_rules)

  security_group_id = aws_security_group.this.id
  type              = "egress"
  description       = var.egress_rules[count.index].description
  from_port         = var.egress_rules[count.index].from_port
  to_port           = var.egress_rules[count.index].to_port
  protocol          = var.egress_rules[count.index].protocol
  cidr_blocks       = var.egress_rules[count.index].cidr_blocks
  ipv6_cidr_blocks  = var.egress_rules[count.index].ipv6_cidr_blocks
  self              = var.egress_rules[count.index].self

  source_security_group_id = length(var.egress_rules[count.index].security_groups) > 0 ? var.egress_rules[count.index].security_groups[0] : null
}
