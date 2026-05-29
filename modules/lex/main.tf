data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

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

  lifecycle {
    ignore_changes = [sample_utterance, fulfillment_code_hook, dialog_code_hook, description]
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
    }
  }

  lifecycle {
    ignore_changes = [value_selection_setting, slot_type_values, description]
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

################################################################################
# Bot Aliases (via CLI — provider doesn't support aws_lexv2models_bot_alias)
################################################################################

locals {
  bot_version = var.bot_version.create ? aws_lexv2models_bot_version.this[0].bot_version : "DRAFT"
}

resource "terraform_data" "alias" {
  for_each = { for a in var.aliases : a.name => a }

  triggers_replace = {
    bot_id      = aws_lexv2models_bot.this.id
    bot_version = coalesce(each.value.bot_version, local.bot_version)
    lambda_arn  = each.value.lambda_arn != null ? each.value.lambda_arn : ""
    locale_id   = each.value.locale_id
  }

  input = {
    bot_id      = aws_lexv2models_bot.this.id
    bot_name    = aws_lexv2models_bot.this.name
    alias_name  = each.value.name
    bot_version = coalesce(each.value.bot_version, local.bot_version)
    lambda_arn  = each.value.lambda_arn != null ? each.value.lambda_arn : ""
    locale_id   = each.value.locale_id
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      # Build locale settings with Lambda if provided
      LOCALE_FLAG=""
      if [ -n "${self.input.lambda_arn}" ]; then
        LOCALE_FLAG="--bot-alias-locale-settings {\"${self.input.locale_id}\":{\"enabled\":true,\"codeHookSpecification\":{\"lambdaCodeHook\":{\"lambdaARN\":\"${self.input.lambda_arn}\",\"codeHookInterfaceVersion\":\"1.0\"}}}}"
      fi

      # Check if alias already exists
      EXISTING=$(aws lexv2-models list-bot-aliases \
        --bot-id "${self.input.bot_id}" \
        --query "botAliasSummaries[?botAliasName=='${self.input.alias_name}'].botAliasId" \
        --output text 2>/dev/null || echo "")

      if [ -n "$EXISTING" ] && [ "$EXISTING" != "None" ]; then
        echo "Alias '${self.input.alias_name}' exists ($EXISTING), updating..."
        aws lexv2-models update-bot-alias \
          --bot-id "${self.input.bot_id}" \
          --bot-alias-id "$EXISTING" \
          --bot-alias-name "${self.input.alias_name}" \
          --bot-version "${self.input.bot_version}" \
          $LOCALE_FLAG
      else
        echo "Creating alias '${self.input.alias_name}'..."
        aws lexv2-models create-bot-alias \
          --bot-id "${self.input.bot_id}" \
          --bot-alias-name "${self.input.alias_name}" \
          --bot-version "${self.input.bot_version}" \
          $LOCALE_FLAG
      fi
    EOT
  }

  depends_on = [aws_lexv2models_bot_version.this, aws_lexv2models_intent.this, aws_lexv2models_slot_type.this]
}

################################################################################
# Connect Resource Policy (allows Connect to invoke bot aliases)
################################################################################

resource "terraform_data" "connect_policy" {
  count = var.connect_integration.enabled ? 1 : 0

  triggers_replace = {
    bot_arn              = aws_lexv2models_bot.this.arn
    connect_instance_arn = var.connect_integration.connect_instance_arn
    account_id           = var.connect_integration.account_id
  }

  input = {
    bot_id               = aws_lexv2models_bot.this.id
    bot_arn              = aws_lexv2models_bot.this.arn
    connect_instance_arn = var.connect_integration.connect_instance_arn
    account_id           = var.connect_integration.account_id
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      POLICY='{"Version":"2012-10-17","Statement":[{"Sid":"AllowConnect","Effect":"Allow","Principal":{"Service":"connect.amazonaws.com"},"Action":["lex:RecognizeText","lex:StartConversation","lex:RecognizeMessageAsync"],"Resource":"${self.input.bot_arn}:*","Condition":{"StringEquals":{"AWS:SourceAccount":"${self.input.account_id}"},"ArnEquals":{"AWS:SourceArn":"${self.input.connect_instance_arn}"}}}]}'

      echo "Adding Connect resource policy..."
      # Try create first; if it already exists, get revision ID and update
      if ! aws lexv2-models create-resource-policy \
        --resource-arn "${self.input.bot_arn}" \
        --policy "$POLICY" 2>/dev/null; then

        echo "Policy exists, updating..."
        REVISION_ID=$(aws lexv2-models describe-resource-policy \
          --resource-arn "${self.input.bot_arn}" \
          --query 'revisionId' --output text)

        aws lexv2-models update-resource-policy \
          --resource-arn "${self.input.bot_arn}" \
          --policy "$POLICY" \
          --expected-revision-id "$REVISION_ID"
      fi

      echo "Resource policy applied"
    EOT
  }

  depends_on = [terraform_data.alias]
}
