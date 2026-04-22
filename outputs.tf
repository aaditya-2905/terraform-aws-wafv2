output "web_acl_id" {
  description = "ID of the created Web ACL"
  value       = module.wafv2.web_acl_id
}

output "web_acl_arn" {
  description = "ARN of the created Web ACL"
  value       = module.wafv2.web_acl_arn
}

output "web_acl_capacity" {
  description = "Capacity of the created Web ACL"
  value       = module.wafv2.web_acl_capacity
}

output "ip_set_arns" {
  description = "Map of IP set names to their ARNs"
  value       = module.wafv2.ip_set_arns
}

output "ip_set_ids" {
  description = "Map of IP set names to their IDs"
  value       = module.wafv2.ip_set_ids
}

output "regex_pattern_set_arns" {
  description = "Map of regex pattern set names to their ARNs"
  value       = module.wafv2.regex_pattern_set_arns
}

output "regex_pattern_set_ids" {
  description = "Map of regex pattern set names to their IDs"
  value       = module.wafv2.regex_pattern_set_ids
}

output "web_acl_associations" {
  description = "List of Web ACL associations"
  value       = module.wafv2.web_acl_associations
}

output "logging_configuration_id" {
  description = "ID of the logging configuration"
  value       = module.wafv2.logging_configuration_id
}
