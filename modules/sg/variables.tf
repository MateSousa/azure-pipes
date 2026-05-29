variable "project_name" {
  type        = string
  description = "Project name prefix for all resources."

  validation {
    condition     = length(var.project_name) <= 32
    error_message = "project_name must be 32 characters or fewer."
  }
}

variable "security_group" {
  type = object({
    name        = string
    description = optional(string, "Managed by Terraform")
    vpc_id      = string
  })
  description = "Security group configuration."

  validation {
    condition     = length("${var.project_name}-${var.security_group.name}") <= 255
    error_message = "Combined security group name (project_name-name) must be 255 characters or fewer."
  }
}

variable "ingress_rules" {
  type = list(object({
    description      = optional(string, "")
    from_port        = number
    to_port          = number
    protocol         = string
    cidr_blocks      = optional(list(string), [])
    ipv6_cidr_blocks = optional(list(string), [])
    security_groups  = optional(list(string), [])
    self             = optional(bool, false)
  }))
  description = "List of ingress rules."
  default     = []
}

variable "egress_rules" {
  type = list(object({
    description      = optional(string, "")
    from_port        = number
    to_port          = number
    protocol         = string
    cidr_blocks      = optional(list(string), [])
    ipv6_cidr_blocks = optional(list(string), [])
    security_groups  = optional(list(string), [])
    self             = optional(bool, false)
  }))
  description = "List of egress rules. Defaults to allow all outbound."
  default = [
    {
      description = "Allow all outbound"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources."
  default     = {}
}
