locals {
  instance_id = var.instance.create ? aws_connect_instance.this[0].id : var.instance.existing_instance_id
}

################################################################################
# Connect Instance
################################################################################

resource "aws_connect_instance" "this" {
  count = var.instance.create ? 1 : 0

  instance_alias           = var.instance.instance_alias
  identity_management_type = var.instance.identity_management_type
  inbound_calls_enabled    = var.instance.inbound_calls_enabled
  outbound_calls_enabled   = var.instance.outbound_calls_enabled
  early_media_enabled      = var.instance.early_media_enabled
  contact_lens_enabled     = var.instance.contact_lens_enabled
}

################################################################################
# Contact Flows
################################################################################

resource "aws_connect_contact_flow" "this" {
  for_each = { for cf in var.contact_flows : cf.name => cf }

  instance_id = local.instance_id
  name        = each.value.name
  description = each.value.description
  type        = each.value.type
  content     = each.value.content_file != null ? file(each.value.content_file) : each.value.content

  tags = var.tags
}

################################################################################
# Contact Flow Modules
################################################################################

resource "aws_connect_contact_flow_module" "this" {
  for_each = { for cfm in var.contact_flow_modules : cfm.name => cfm }

  instance_id = local.instance_id
  name        = each.value.name
  description = each.value.description
  content     = each.value.content_file != null ? file(each.value.content_file) : each.value.content

  tags = var.tags
}

################################################################################
# Hours of Operation
################################################################################

resource "aws_connect_hours_of_operation" "this" {
  for_each = { for h in var.hours_of_operation : h.name => h }

  instance_id = local.instance_id
  name        = each.value.name
  description = each.value.description
  time_zone   = each.value.time_zone

  dynamic "config" {
    for_each = each.value.config
    content {
      day = config.value.day
      start_time {
        hours   = config.value.start_time.hours
        minutes = config.value.start_time.minutes
      }
      end_time {
        hours   = config.value.end_time.hours
        minutes = config.value.end_time.minutes
      }
    }
  }

  tags = var.tags
}

################################################################################
# Queues
################################################################################

resource "aws_connect_queue" "this" {
  for_each = { for q in var.queues : q.name => q }

  instance_id           = local.instance_id
  name                  = each.value.name
  description           = each.value.description
  hours_of_operation_id = aws_connect_hours_of_operation.this[each.value.hours_of_operation_name].hours_of_operation_id
  max_contacts          = each.value.max_contacts

  tags = var.tags
}
