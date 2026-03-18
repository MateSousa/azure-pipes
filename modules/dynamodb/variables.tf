variable "project_name" {
  description = "Name of the project, used as a prefix for resource names."
  type        = string

  validation {
    condition     = length(var.project_name) <= 32
    error_message = "project_name must be 32 characters or fewer."
  }
}

variable "table" {
  description = "Configuration for the DynamoDB table."
  type = object({
    name                        = string
    billing_mode                = optional(string, "PAY_PER_REQUEST")
    hash_key                    = string
    range_key                   = optional(string, null)
    read_capacity               = optional(number, null)
    write_capacity              = optional(number, null)
    table_class                 = optional(string, "STANDARD")
    deletion_protection_enabled = optional(bool, false)
    stream_enabled              = optional(bool, false)
    stream_view_type            = optional(string, null)
  })

  validation {
    condition     = length(var.table.name) <= 255
    error_message = "table.name must be 255 characters or fewer."
  }

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.table.billing_mode)
    error_message = "table.billing_mode must be one of: PAY_PER_REQUEST, PROVISIONED."
  }

  validation {
    condition     = var.table.billing_mode != "PROVISIONED" || var.table.read_capacity != null
    error_message = "table.read_capacity is required when billing_mode is PROVISIONED."
  }

  validation {
    condition     = contains(["STANDARD", "STANDARD_INFREQUENT_ACCESS"], var.table.table_class)
    error_message = "table.table_class must be one of: STANDARD, STANDARD_INFREQUENT_ACCESS."
  }

  validation {
    condition     = var.table.stream_view_type == null ? true : contains(["NEW_IMAGE", "OLD_IMAGE", "NEW_AND_OLD_IMAGES", "KEYS_ONLY"], var.table.stream_view_type)
    error_message = "table.stream_view_type must be one of: NEW_IMAGE, OLD_IMAGE, NEW_AND_OLD_IMAGES, KEYS_ONLY, or null."
  }
}

variable "attributes" {
  description = "List of attribute definitions for the DynamoDB table."
  type = list(object({
    name = string
    type = string
  }))

  validation {
    condition     = alltrue([for attr in var.attributes : contains(["S", "N", "B"], attr.type)])
    error_message = "Each attribute type must be one of: S, N, B."
  }
}

variable "global_secondary_indexes" {
  description = "List of global secondary indexes for the DynamoDB table."
  type = list(object({
    name               = string
    hash_key           = string
    range_key          = optional(string)
    projection_type    = string
    non_key_attributes = optional(list(string))
    read_capacity      = optional(number)
    write_capacity     = optional(number)
  }))
  default = []
}

variable "local_secondary_indexes" {
  description = "List of local secondary indexes for the DynamoDB table."
  type = list(object({
    name               = string
    range_key          = string
    projection_type    = string
    non_key_attributes = optional(list(string))
  }))
  default = []
}

variable "ttl" {
  description = "TTL configuration for the DynamoDB table."
  type = object({
    enabled        = bool
    attribute_name = string
  })
  default = null
}

variable "encryption" {
  description = "Server-side encryption configuration for the DynamoDB table."
  type = object({
    enabled     = optional(bool, true)
    kms_key_arn = optional(string, null)
  })
  default = {}
}

variable "point_in_time_recovery" {
  description = "Point-in-time recovery configuration for the DynamoDB table."
  type = object({
    enabled = optional(bool, true)
  })
  default = {}
}

variable "replicas" {
  description = "List of replica configurations for global tables."
  type = list(object({
    region_name = string
    kms_key_arn = optional(string, null)
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to the DynamoDB table."
  type        = map(string)
  default     = {}
}
