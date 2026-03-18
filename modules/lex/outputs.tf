output "bot_id" {
  description = "The ID of the Lex V2 bot."
  value       = aws_lexv2models_bot.this.id
}

output "bot_arn" {
  description = "The ARN of the Lex V2 bot."
  value       = aws_lexv2models_bot.this.arn
}

output "bot_name" {
  description = "The name of the Lex V2 bot."
  value       = aws_lexv2models_bot.this.name
}

output "locale_ids" {
  description = "Map of locale keys to locale IDs."
  value       = { for k, v in aws_lexv2models_bot_locale.this : k => v.locale_id }
}

output "intent_ids" {
  description = "Map of intent keys to intent IDs."
  value       = { for k, v in aws_lexv2models_intent.this : k => v.intent_id }
}

output "slot_type_ids" {
  description = "Map of slot type keys to slot type IDs."
  value       = { for k, v in aws_lexv2models_slot_type.this : k => v.slot_type_id }
}

output "bot_version" {
  description = "The bot version number, if created."
  value       = try(aws_lexv2models_bot_version.this[0].bot_version, null)
}

