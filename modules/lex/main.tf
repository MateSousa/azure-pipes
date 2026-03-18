################################################################################
# Bot
################################################################################

resource "aws_lexv2models_bot" "this" {
  name        = "${var.project_name}-${var.bot.name}"
  description = var.bot.description
  role_arn    = var.bot.role_arn
  type        = var.bot.type

  data_privacy {
    child_directed = var.bot.data_privacy.child_directed
  }

  idle_session_ttl_in_seconds = var.bot.idle_session_ttl_in_seconds

  tags = var.tags
}

################################################################################
# Bot Locales
################################################################################

resource "aws_lexv2models_bot_locale" "this" {
  for_each = { for l in var.locales : l.locale_id => l }

  bot_id                           = aws_lexv2models_bot.this.id
  bot_version                      = "DRAFT"
  locale_id                        = each.value.locale_id
  description                      = each.value.description
  n_lu_intent_confidence_threshold = each.value.nlu_intent_confidence_threshold

  dynamic "voice_settings" {
    for_each = each.value.voice_settings != null ? [each.value.voice_settings] : []
    content {
      voice_id = voice_settings.value.voice_id
      engine   = voice_settings.value.engine
    }
  }
}

################################################################################
# Intents
################################################################################

locals {
  intents = flatten([
    for locale_id, intent_list in var.intents : [
      for intent in intent_list : merge(intent, { locale_id = locale_id })
    ]
  ])
}

resource "aws_lexv2models_intent" "this" {
  for_each = { for i in local.intents : "${i.locale_id}/${i.name}" => i }

  bot_id      = aws_lexv2models_bot.this.id
  bot_version = aws_lexv2models_bot_locale.this[each.value.locale_id].bot_version
  locale_id   = each.value.locale_id
  name        = each.value.name
  description = each.value.description

  parent_intent_signature = each.value.parent_intent_signature

  dynamic "sample_utterance" {
    for_each = each.value.sample_utterances
    content {
      utterance = sample_utterance.value.utterance
    }
  }

  dynamic "fulfillment_code_hook" {
    for_each = each.value.fulfillment_code_hook != null ? [each.value.fulfillment_code_hook] : []
    content {
      enabled = fulfillment_code_hook.value.enabled
    }
  }

  dynamic "dialog_code_hook" {
    for_each = each.value.dialog_code_hook != null ? [each.value.dialog_code_hook] : []
    content {
      enabled = dialog_code_hook.value.enabled
    }
  }
}

################################################################################
# Slot Types
################################################################################

locals {
  slot_types = flatten([
    for locale_id, st_list in var.slot_types : [
      for st in st_list : merge(st, { locale_id = locale_id })
    ]
  ])
}

resource "aws_lexv2models_slot_type" "this" {
  for_each = { for st in local.slot_types : "${st.locale_id}/${st.name}" => st }

  bot_id      = aws_lexv2models_bot.this.id
  bot_version = aws_lexv2models_bot_locale.this[each.value.locale_id].bot_version
  locale_id   = each.value.locale_id
  name        = each.value.name
  description = each.value.description

  dynamic "value_selection_setting" {
    for_each = each.value.value_selection_setting != null ? [each.value.value_selection_setting] : []
    content {
      resolution_strategy = value_selection_setting.value.resolution_strategy
    }
  }

  dynamic "slot_type_values" {
    for_each = each.value.values
    content {
      sample_value {
        value = slot_type_values.value.value
      }
      # Note: synonyms would need additional dynamic blocks if supported
    }
  }
}

################################################################################
# Bot Version
################################################################################

resource "aws_lexv2models_bot_version" "this" {
  count       = var.bot_version.create ? 1 : 0
  bot_id      = aws_lexv2models_bot.this.id
  description = var.bot_version.description

  locale_specification = {
    for locale_id, locale in aws_lexv2models_bot_locale.this : locale_id => {
      source_bot_version = "DRAFT"
    }
  }
}

