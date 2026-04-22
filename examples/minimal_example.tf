# Minimal WAFv2 Example
# This example shows a basic setup with managed rule groups and rate limiting

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "wafv2_minimal" {
  source = "aaditya-2905/wafv2/aws"

  name   = "example-waf-minimal"
  scope  = "REGIONAL"
  region = var.aws_region

  description = "Minimal WAF configuration with AWS managed rules"

  # Default action - allow all traffic by default
  default_action = {
    allow = {}
  }

  # Visibility configuration for CloudWatch metrics
  visibility_config = {
    cloudwatch_metrics_enabled = true
    metric_name                = "example-waf-minimal"
    sampled_requests_enabled   = true
  }

  # Rate limiting rule
  rate_limit_rules = [
    {
      name                    = "rate-limit-rule"
      priority                = 1
      limit                   = 2000
      aggregate_key_type      = "IP"
      action                  = "BLOCK"
      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "rate-limit-rule"
        sampled_requests_enabled   = true
      }
    }
  ]

  # AWS managed rule groups
  managed_rule_groups = [
    {
      vendor_name = "AWS"
      name        = "AWSManagedRulesCommonRuleSet"
      version     = "4.3"
    }
  ]

  tags = {
    Environment = "dev"
    Project     = "example"
  }
}

# Output the Web ACL ID
output "web_acl_id" {
  description = "ID of the created Web ACL"
  value       = module.wafv2_minimal.web_acl_id
}

output "web_acl_arn" {
  description = "ARN of the created Web ACL"
  value       = module.wafv2_minimal.web_acl_arn
}
