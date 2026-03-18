variable "project_name" {
  description = "Project name used as a prefix for resource naming."
  type        = string

  validation {
    condition     = length(var.project_name) <= 32
    error_message = "project_name must be 32 characters or fewer."
  }
}

variable "alb" {
  description = "Configuration for the Application Load Balancer."
  type = object({
    name                             = string
    internal                         = optional(bool, false)
    idle_timeout                     = optional(number, 60)
    enable_deletion_protection       = optional(bool, false)
    enable_http2                     = optional(bool, true)
    drop_invalid_header_fields       = optional(bool, true)
    enable_cross_zone_load_balancing = optional(bool, true)
  })

  validation {
    condition     = length("${var.project_name}-${var.alb.name}") <= 32
    error_message = "Combined ALB name (project_name-alb.name) must be 32 characters or fewer."
  }

  validation {
    condition     = var.alb.idle_timeout >= 1 && var.alb.idle_timeout <= 4000
    error_message = "idle_timeout must be between 1 and 4000."
  }
}

variable "network" {
  description = "Network configuration for the ALB."
  type = object({
    vpc_id             = string
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
}

variable "target_group" {
  description = "Target group configuration."
  type = object({
    name                 = string
    port                 = number
    protocol             = optional(string, "HTTP")
    target_type          = optional(string, "ip")
    deregistration_delay = optional(number, 300)
    slow_start           = optional(number, 0)
    health_check = optional(object({
      enabled             = optional(bool, true)
      path                = optional(string, "/")
      port                = optional(string, "traffic-port")
      protocol            = optional(string, "HTTP")
      healthy_threshold   = optional(number, 3)
      unhealthy_threshold = optional(number, 3)
      timeout             = optional(number, 5)
      interval            = optional(number, 30)
      matcher             = optional(string, "200")
    }))
    stickiness = optional(object({
      type            = string
      cookie_duration = optional(number, 86400)
      enabled         = optional(bool, true)
    }), null)
  })

  validation {
    condition     = var.target_group.port >= 1 && var.target_group.port <= 65535
    error_message = "target_group.port must be between 1 and 65535."
  }

  validation {
    condition     = contains(["HTTP", "HTTPS"], var.target_group.protocol)
    error_message = "target_group.protocol must be one of: HTTP, HTTPS."
  }

  validation {
    condition     = contains(["ip", "instance", "lambda", "alb"], var.target_group.target_type)
    error_message = "target_group.target_type must be one of: ip, instance, lambda, alb."
  }
}

variable "listener" {
  description = "Listener configuration for the ALB."
  type = object({
    port            = number
    protocol        = string
    ssl_policy      = optional(string, null)
    certificate_arn = optional(string, null)
  })

  validation {
    condition     = var.listener.port >= 1 && var.listener.port <= 65535
    error_message = "listener.port must be between 1 and 65535."
  }

  validation {
    condition     = contains(["HTTP", "HTTPS"], var.listener.protocol)
    error_message = "listener.protocol must be one of: HTTP, HTTPS."
  }

  validation {
    condition     = var.listener.protocol != "HTTPS" || var.listener.certificate_arn != null
    error_message = "certificate_arn is required when listener protocol is HTTPS."
  }
}

variable "https_redirect" {
  description = "Whether to create an HTTP to HTTPS redirect listener on port 80."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
