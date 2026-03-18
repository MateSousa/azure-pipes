variable "project_name" {
  description = "Name of the project."
  type        = string

  validation {
    condition     = length(var.project_name) <= 32
    error_message = "project_name must be 32 characters or fewer."
  }
}

variable "instance" {
  description = "Connect instance configuration. Either create a new instance or reference an existing one."
  type = object({
    create                   = optional(bool, false)
    existing_instance_id     = optional(string, null)
    instance_alias           = optional(string, null)
    identity_management_type = optional(string, "CONNECT_MANAGED")
    inbound_calls_enabled    = optional(bool, true)
    outbound_calls_enabled   = optional(bool, true)
    early_media_enabled      = optional(bool, true)
    contact_lens_enabled     = optional(bool, false)
  })

  validation {
    condition     = var.instance.create != (var.instance.existing_instance_id != null)
    error_message = "Either create a new instance (create=true) or provide an existing_instance_id, but not both."
  }

  validation {
    condition     = contains(["SAML", "CONNECT_MANAGED", "EXISTING_DIRECTORY"], var.instance.identity_management_type)
    error_message = "identity_management_type must be one of: SAML, CONNECT_MANAGED, EXISTING_DIRECTORY."
  }
}

variable "contact_flows" {
  description = "List of Connect contact flows to create."
  type = list(object({
    name         = string
    description  = optional(string, "")
    type         = optional(string, "CONTACT_FLOW")
    content_file = optional(string, null)
    content      = optional(string, null)
  }))
  default = []

  validation {
    condition = alltrue([
      for cf in var.contact_flows : contains([
        "CONTACT_FLOW",
        "CUSTOMER_QUEUE",
        "CUSTOMER_HOLD",
        "CUSTOMER_WHISPER",
        "AGENT_HOLD",
        "AGENT_WHISPER",
        "OUTBOUND_WHISPER",
        "AGENT_TRANSFER",
        "QUEUE_TRANSFER"
      ], cf.type)
    ])
    error_message = "Each contact flow type must be one of: CONTACT_FLOW, CUSTOMER_QUEUE, CUSTOMER_HOLD, CUSTOMER_WHISPER, AGENT_HOLD, AGENT_WHISPER, OUTBOUND_WHISPER, AGENT_TRANSFER, QUEUE_TRANSFER."
  }
}

variable "contact_flow_modules" {
  description = "List of Connect contact flow modules to create."
  type = list(object({
    name         = string
    description  = optional(string, "")
    content_file = optional(string, null)
    content      = optional(string, null)
  }))
  default = []
}

variable "hours_of_operation" {
  description = "List of hours of operation to create."
  type = list(object({
    name        = string
    description = optional(string, "")
    time_zone   = string
    config = list(object({
      day = string
      start_time = object({
        hours   = number
        minutes = number
      })
      end_time = object({
        hours   = number
        minutes = number
      })
    }))
  }))
  default = []
}

variable "queues" {
  description = "List of Connect queues to create."
  type = list(object({
    name                    = string
    description             = optional(string, "")
    hours_of_operation_name = string
    max_contacts            = optional(number, null)
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
