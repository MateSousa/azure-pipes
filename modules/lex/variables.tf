variable "project_name" {
  type        = string
  description = "Project name prefix for all resources."

  validation {
    condition     = length(var.project_name) <= 32
    error_message = "project_name must be 32 characters or fewer."
  }
}

variable "bot" {
  type = object({
    name        = string
    description = optional(string, "")
    role_arn    = string
    data_privacy = optional(object({
      child_directed = bool
    }), { child_directed = false })
    idle_session_ttl_in_seconds = optional(number, 300)
    type                        = optional(string, "Bot")
  })
  description = "Lex V2 bot configuration."

  validation {
    condition     = length("${var.project_name}-${var.bot.name}") <= 100
    error_message = "Combined bot name (project_name-bot.name) must be 100 characters or fewer."
  }

  validation {
    condition     = startswith(var.bot.role_arn, "arn:")
    error_message = "bot.role_arn must be a valid ARN (starts with 'arn:')."
  }

  validation {
    condition     = var.bot.idle_session_ttl_in_seconds >= 60 && var.bot.idle_session_ttl_in_seconds <= 86400
    error_message = "bot.idle_session_ttl_in_seconds must be between 60 and 86400."
  }
}

variable "locales" {
  type = list(object({
    locale_id                       = string
    description                     = optional(string, "")
    nlu_intent_confidence_threshold = optional(number, 0.4)
    voice_settings = optional(object({
      voice_id = string
      engine   = optional(string, "neural")
    }), null)
  }))
  description = "List of bot locale configurations."
  default     = []
}

variable "intents" {
  type = map(list(object({
    name                    = string
    description             = optional(string, "")
    parent_intent_signature = optional(string, null)
    sample_utterances = optional(list(object({
      utterance = string
    })), [])
    fulfillment_code_hook = optional(object({
      enabled = bool
    }), null)
    dialog_code_hook = optional(object({
      enabled = bool
    }), null)
  })))
  description = "Map of locale_id to list of intent configurations."
  default     = {}
}

variable "slot_types" {
  type = map(list(object({
    name        = string
    description = optional(string, "")
    value_selection_setting = optional(object({
      resolution_strategy = string
    }), null)
    values = optional(list(object({
      value    = string
      synonyms = optional(list(string), [])
    })), [])
  })))
  description = "Map of locale_id to list of slot type configurations."
  default     = {}
}

variable "bot_version" {
  type = object({
    create      = bool
    description = optional(string, "")
  })
  description = "Bot version configuration."
  default = {
    create      = false
    description = ""
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources."
  default     = {}
}
