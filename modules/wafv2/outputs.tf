output "web_acl_id" {
  description = "ID of the created Web ACL"
  value       = aws_wafv2_web_acl.this.id
}

output "web_acl_arn" {
  description = "ARN of the created Web ACL"
  value       = aws_wafv2_web_acl.this.arn
}

output "web_acl_capacity" {
  description = "Capacity of the created Web ACL"
  value       = aws_wafv2_web_acl.this.capacity
}

output "ip_set_arns" {
  description = "Map of IP set names to their ARNs"
  value = {
    for name, ip_set in aws_wafv2_ip_set.this : name => ip_set.arn
  }
}

output "ip_set_ids" {
  description = "Map of IP set names to their IDs"
  value = {
    for name, ip_set in aws_wafv2_ip_set.this : name => ip_set.id
  }
}

output "regex_pattern_set_arns" {
  description = "Map of regex pattern set names to their ARNs"
  value = {
    for name, pattern_set in aws_wafv2_regex_pattern_set.this : name => pattern_set.arn
  }
}

output "regex_pattern_set_ids" {
  description = "Map of regex pattern set names to their IDs"
  value = {
    for name, pattern_set in aws_wafv2_regex_pattern_set.this : name => pattern_set.id
  }
}

output "web_acl_associations" {
  description = "Map of Web ACL association IDs"
  value = {
    for arn, assoc in aws_wafv2_web_acl_association.this : arn => assoc.id
  }
}

output "logging_configuration_id" {
  description = "ID of the logging configuration"
  value       = try(aws_wafv2_web_acl_logging_configuration.this[0].id, null)
}

output "logging_configuration_resource_arn" {
  description = "ARN of the resource associated with the logging configuration"
  value       = try(aws_wafv2_web_acl_logging_configuration.this[0].resource_arn, null)
}
