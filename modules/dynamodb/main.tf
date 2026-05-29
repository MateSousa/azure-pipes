resource "aws_dynamodb_table" "this" {
  name                        = "${var.project_name}-${var.table.name}"
  billing_mode                = var.table.billing_mode
  hash_key                    = var.table.hash_key
  range_key                   = var.table.range_key
  read_capacity               = var.table.read_capacity
  write_capacity              = var.table.write_capacity
  table_class                 = var.table.table_class
  deletion_protection_enabled = var.table.deletion_protection_enabled
  stream_enabled              = var.table.stream_enabled
  stream_view_type            = var.table.stream_view_type

  dynamic "attribute" {
    for_each = var.attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  dynamic "global_secondary_index" {
    for_each = var.global_secondary_indexes
    content {
      name               = global_secondary_index.value.name
      hash_key           = global_secondary_index.value.hash_key
      range_key          = global_secondary_index.value.range_key
      projection_type    = global_secondary_index.value.projection_type
      non_key_attributes = global_secondary_index.value.non_key_attributes
      read_capacity      = global_secondary_index.value.read_capacity
      write_capacity     = global_secondary_index.value.write_capacity
    }
  }

  dynamic "local_secondary_index" {
    for_each = var.local_secondary_indexes
    content {
      name               = local_secondary_index.value.name
      range_key          = local_secondary_index.value.range_key
      projection_type    = local_secondary_index.value.projection_type
      non_key_attributes = local_secondary_index.value.non_key_attributes
    }
  }

  dynamic "ttl" {
    for_each = var.ttl != null ? [var.ttl] : []
    content {
      enabled        = ttl.value.enabled
      attribute_name = ttl.value.attribute_name
    }
  }

  server_side_encryption {
    enabled     = var.encryption.enabled
    kms_key_arn = var.encryption.kms_key_arn
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery.enabled
  }

  dynamic "replica" {
    for_each = var.replicas
    content {
      region_name = replica.value.region_name
      kms_key_arn = replica.value.kms_key_arn
    }
  }

  tags = var.tags
}
