# Terraform AWS WAFv2 Module

A production-ready, comprehensive Terraform module for deploying AWS WAFv2 Web ACLs with full support for managed rules, custom rules, IP sets, regex pattern sets, and logging configuration.

## Features

- ✅ **Modular Architecture**: Clean separation between interface (root) and implementation (internal module)
- ✅ **Managed Rule Groups**: Support for AWS managed rule groups (CRS, Known Bad Inputs, Anonymous IP, etc.)
- ✅ **Custom Rules**: Support for all custom rule types:
  - Rate limiting rules
  - Geo-blocking rules
  - Byte match rules
  - Size constraint rules
  - SQL injection detection rules
  - XSS detection rules
  - IP set references
  - Regex pattern set references
- ✅ **Dynamic Configuration**: All rule lists can be configured through variables
- ✅ **IP Sets & Regex Patterns**: Inline creation of IP sets and regex pattern sets
- ✅ **Logging**: CloudWatch Logs or Kinesis Firehose integration
- ✅ **Multi-Resource Association**: Associate Web ACL with ALB, CloudFront, API Gateway
- ✅ **Custom Response Bodies**: Define custom responses for blocked requests
- ✅ **Best Practices**: Follows terraform-aws-modules conventions

## Module Structure

```
terraform-aws-wafv2/
├── main.tf              # Root module - passes variables to internal module
├── variables.tf         # Root module - variable definitions
├── outputs.tf           # Root module - output passthrough
├── versions.tf          # Provider configuration
├── modules/
│   └── wafv2/
│       ├── main.tf      # Internal module - resource creation with dynamic blocks
│       ├── variables.tf # Internal module - variable definitions (same as root)
│       ├── outputs.tf   # Internal module - resource outputs
│       └── versions.tf  # Provider requirements
└── examples/
    ├── minimal_example.tf     # Minimal configuration
    ├── minimal_variables.tf
    ├── production_example.tf  # Full production configuration
    └── production_variables.tf
```

## Usage

### Minimal Example

```hcl
module "wafv2" {
  source = "aaditya-2905/wafv2/aws"

  name   = "my-waf"
  scope  = "REGIONAL"
  region = "us-east-1"

  default_action = {
    allow = {}
  }

  visibility_config = {
    cloudwatch_metrics_enabled = true
    metric_name                = "my-waf"
    sampled_requests_enabled   = true
  }

  managed_rule_groups = [
    {
      vendor_name = "AWS"
      name        = "AWSManagedRulesCommonRuleSet"
      version     = "4.3"
    }
  ]

  rate_limit_rules = [
    {
      name               = "rate-limit"
      priority           = 1
      limit              = 2000
      action             = "BLOCK"
      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "rate-limit"
        sampled_requests_enabled   = true
      }
    }
  ]

  tags = {
    Environment = "dev"
  }
}
```

### Production Example

See `examples/production_example.tf` for a comprehensive example including:
- Multiple AWS managed rule groups
- Custom IP sets and regex pattern sets
- Complex rule configurations
- Logging configuration
- Multiple rule types (rate limiting, geo-blocking, SQL injection detection, XSS detection)

## Variables

### Core Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `region` | string | - | AWS region for resources |
| `name` | string | - | Name of the Web ACL |
| `description` | string | "" | Description of the Web ACL |
| `scope` | string | "REGIONAL" | Scope: REGIONAL or CLOUDFRONT |
| `tags` | map(string) | {} | Tags to apply to resources |

### Actions and Visibility

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `default_action` | object | `{ allow = {} }` | Default action (allow or block) |
| `visibility_config` | object | - | CloudWatch metrics configuration |
| `custom_response_bodies` | map(object) | {} | Custom response bodies for blocks |

### Rules Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `rules` | list(object) | [] | Custom rules with full statement support |
| `managed_rule_groups` | list(object) | [] | AWS managed rule groups |
| `rate_limit_rules` | list(object) | [] | Rate limiting rules |
| `geo_match_rules` | list(object) | [] | Geographic blocking rules |
| `byte_match_rules` | list(object) | [] | Byte matching rules |
| `size_constraint_rules` | list(object) | [] | Request size constraints |
| `sqli_match_rules` | list(object) | [] | SQL injection detection |
| `xss_match_rules` | list(object) | [] | XSS attack detection |

### IP Sets and Pattern Sets

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `ip_set_references` | map(object) | {} | IP sets to create |
| `regex_pattern_sets` | map(object) | {} | Regex pattern sets to create |

### Logging and Association

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `logging_configuration` | object | {} | CloudWatch Logs or Firehose configuration |
| `association_resource_arns` | list(string) | [] | Resources to associate with Web ACL |

## Outputs

| Output | Description |
|--------|-------------|
| `web_acl_id` | ID of the created Web ACL |
| `web_acl_arn` | ARN of the created Web ACL |
| `web_acl_capacity` | Web ACL capacity (WCUs) |
| `ip_set_arns` | Map of IP set names to ARNs |
| `ip_set_ids` | Map of IP set names to IDs |
| `regex_pattern_set_arns` | Map of regex pattern set names to ARNs |
| `regex_pattern_set_ids` | Map of regex pattern set names to IDs |
| `web_acl_associations` | Map of Web ACL association IDs |
| `logging_configuration_id` | ID of logging configuration |

## Advanced Usage

### Using IP Sets in Rules

```hcl
module "wafv2" {
  source = "aaditya-2905/wafv2/aws"

  ip_set_references = {
    "corporate-ips" = {
      scope              = "REGIONAL"
      address_definition = ["203.0.113.0/24"]
      description        = "Corporate IPs"
    }
  }

  rules = [
    {
      name     = "allow-corporate"
      priority = 0
      action   = "ALLOW"
      visibility_config = {
        cloudwatch_metrics_enabled = true
        metric_name                = "allow-corporate"
        sampled_requests_enabled   = true
      }
      ip_set_reference_statement = {
        arn = module.wafv2.ip_set_arns["corporate-ips"]
      }
    }
  ]

  # ... rest of configuration
}
```

### Conditional Resource Association

```hcl
module "wafv2" {
  source = "aaditya-2905/wafv2/aws"
  
  # ... other configuration ...

  association_resource_arns = var.associate_alb ? [
    aws_lb.main.arn
  ] : []
}
```

### Custom Response Bodies

```hcl
module "wafv2" {
  source = "aaditya-2905/wafv2/aws"

  custom_response_bodies = {
    blocked = {
      content      = jsonencode({ error = "Access Denied" })
      content_type = "APPLICATION_JSON"
    }
    rate_limited = {
      content      = "Rate limit exceeded"
      content_type = "TEXT_PLAIN"
    }
  }

  default_action = {
    block = {
      custom_response = {
        custom_response_body_key = "blocked"
        response_code            = 403
      }
    }
  }

  # ... rest of configuration ...
}
```

## Rule Priority Order

Rules are processed in priority order. The module assigns priority ranges automatically:

- 0-999: Custom rules from `rules` variable
- 1000-1999: `rate_limit_rules`
- 2000-2999: `geo_match_rules`
- 3000-3999: `byte_match_rules`
- 4000-4999: `size_constraint_rules`
- 5000-5999: `sqli_match_rules`
- 6000-6999: `xss_match_rules`
- 10000+: `managed_rule_groups`

Explicitly set priorities in the `rules` variable to override this behavior.

## Logging Configuration

### CloudWatch Logs

```hcl
logging_configuration = {
  cloudwatch_logs_log_group = aws_cloudwatch_log_group.waf_logs.arn
  logging_filter = [
    {
      default_behavior = "KEEP"
      filters = [
        {
          behavior    = "KEEP"
          requirement = "MEETS_ALL"
          condition = [
            {
              action_condition = {
                action = "BLOCK"
              }
            }
          ]
        }
      ]
    }
  ]
}
```

### Kinesis Firehose

```hcl
logging_configuration = {
  kinesis_firehose_stream_arn = aws_kinesis_firehose_delivery_stream.waf.arn
}
```

## AWS Managed Rule Groups

Common AWS managed rule groups:

- `AWSManagedRulesCommonRuleSet` - Core ruleset for common web exploits
- `AWSManagedRulesKnownBadInputsRuleSet` - Known bad inputs
- `AWSManagedRulesAnonymousIPList` - Anonymous IPs
- `AWSManagedRulesAmazonIpReputationList` - AWS IP reputation list
- `AWSManagedRulesSQLiRuleSet` - SQL injection specific
- `AWSManagedRulesLinuxRuleSet` - Linux-specific attacks
- `AWSManagedRulesWindowsRuleSet` - Windows-specific attacks

## Requirements

- Terraform >= 1.0
- AWS Provider >= 5.0

## Architecture

This module follows the **wrapper pattern** with a clean separation of concerns:

- **Root Module**: Serves as the interface layer, only containing variable definitions and module invocation
- **Internal Module (`modules/wafv2`)**: Contains all the implementation logic with dynamic blocks

This architecture provides:
- Clear variable interface
- Easy-to-understand resource creation logic
- Simplified maintenance and testing
- Better composability when reusing across projects

## Best Practices

1. **Start with COUNT action**: Use `action = "COUNT"` to observe traffic before blocking
2. **Monitor metrics**: Enable CloudWatch metrics for all rules
3. **Use managed rules**: Always include `AWSManagedRulesCommonRuleSet` at minimum
4. **Log everything**: Configure logging for security analysis
5. **Test rule updates**: Apply rule changes to non-production environments first
6. **Use tags**: Tag resources for cost allocation and organization

## Troubleshooting

### Rule Priority Conflicts

If you encounter priority conflicts, either:
1. Use the rule priority ranges documented above
2. Explicitly set all rule priorities to avoid conflicts

### Capacity Exceeded

WAF has a Web ACL Capacity limit (default 1,500 WCUs). If exceeded:
1. Check `web_acl_capacity` output
2. Reduce the number of rules
3. Use managed rule group exclusions to reduce capacity

### Logging Not Working

Ensure:
1. CloudWatch log group or Firehose exists
2. IAM permissions for WAF to write logs
3. Log group retention settings are appropriate

## Contributing

This module follows terraform-aws-modules standards and best practices.