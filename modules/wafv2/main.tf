locals {

  managed_rule_groups_list = [
    for idx, mrg in var.managed_rule_groups : {
      priority = 10000 + idx
      name     = "${mrg.vendor_name}_${mrg.name}"
      rule     = mrg
      type     = "managed_rule_group"
    }
  ]

  rate_limit_rules_list = [
    for idx, rule in var.rate_limit_rules : {
      priority = 1000 + idx
      name     = rule.name
      rule     = rule
      type     = "rate_limit"
    }
  ]

  geo_match_rules_list = [
    for idx, rule in var.geo_match_rules : {
      priority = 2000 + idx
      name     = rule.name
      rule     = rule
      type     = "geo_match"
    }
  ]

  byte_match_rules_list = [
    for idx, rule in var.byte_match_rules : {
      priority = 3000 + idx
      name     = rule.name
      rule     = rule
      type     = "byte_match"
    }
  ]

  size_constraint_rules_list = [
    for idx, rule in var.size_constraint_rules : {
      priority = 4000 + idx
      name     = rule.name
      rule     = rule
      type     = "size_constraint"
    }
  ]

  sqli_match_rules_list = [
    for idx, rule in var.sqli_match_rules : {
      priority = 5000 + idx
      name     = rule.name
      rule     = rule
      type     = "sqli_match"
    }
  ]

  xss_match_rules_list = [
    for idx, rule in var.xss_match_rules : {
      priority = 6000 + idx
      name     = rule.name
      rule     = rule
      type     = "xss_match"
    }
  ]

  # Map for IP set references
  ip_set_map = {
    for name, ip_set in aws_wafv2_ip_set.this : name => {
      id  = ip_set.id
      arn = ip_set.arn
    }
  }

  # Map for regex pattern set references
  regex_pattern_set_map = {
    for name, pattern_set in aws_wafv2_regex_pattern_set.this : name => {
      id  = pattern_set.id
      arn = pattern_set.arn
    }
  }
}

# Custom response bodies
resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count        = length(var.logging_configuration) > 0 ? 1 : 0
  resource_arn = aws_wafv2_web_acl.this.arn
  log_destination_configs = compact([
    var.logging_configuration.cloudwatch_logs_log_group,
    var.logging_configuration.kinesis_firehose_stream_arn,
    var.logging_configuration.s3_bucket != null ? "arn:aws:s3:::${var.logging_configuration.s3_bucket}" : null
  ])

  dynamic "redacted_fields" {
    for_each = length(keys(var.logging_configuration)) > 0 ? [1] : []
    content {
      # This can be expanded to include specific redacted fields if needed
    }
  }

  dynamic "logging_filter" {
    for_each = var.logging_configuration.logging_filter != null ? var.logging_configuration.logging_filter : []
    content {
      default_behavior = logging_filter.value.default_behavior

      dynamic "filter" {
        for_each = logging_filter.value.filters
        content {
          behavior    = filter.value.behavior
          requirement = filter.value.requirement

          dynamic "condition" {
            for_each = filter.value.condition
            content {
              dynamic "action_condition" {
                for_each = condition.value.action_condition != null ? [condition.value.action_condition] : []
                content {
                  action = action_condition.value.action
                }
              }

              dynamic "label_name_condition" {
                for_each = condition.value.label_name_condition != null ? [condition.value.label_name_condition] : []
                content {
                  label_name = label_name_condition.value.label_name
                }
              }

              # ip_set_reference_condition removed — logging_filter Condition supports only
              # action_condition and label_name_condition per provider v5 docs.
            }
          }
        }
      }
    }
  }

  depends_on = [aws_wafv2_web_acl.this]
}

# IP Sets
resource "aws_wafv2_ip_set" "this" {
  for_each = var.ip_set_references

  name               = each.key
  description        = each.value.description
  scope              = each.value.scope
  ip_address_version = "IPV4"
  addresses          = each.value.address_definition

  tags = merge(
    var.tags,
    each.value.tags
  )
}

# Regex Pattern Sets
resource "aws_wafv2_regex_pattern_set" "this" {
  for_each = var.regex_pattern_sets

  name        = each.key
  description = each.value.description
  scope       = each.value.scope

  dynamic "regular_expression" {
    for_each = each.value.regular_expressions
    content {
      regex_string = regex_string.value.regex_string
    }
  }

  tags = merge(
    var.tags,
    each.value.tags
  )
}

# Main Web ACL Resource
resource "aws_wafv2_web_acl" "this" {
  name        = var.name
  description = var.description
  scope       = var.scope

  # Default action
  dynamic "default_action" {
    for_each = var.default_action.allow != null ? [var.default_action.allow] : []
    content {
      allow {}
    }
  }

  dynamic "default_action" {
    for_each = var.default_action.block != null ? [var.default_action.block] : []
    content {
      block {

        dynamic "custom_response" {
          for_each = try(default_action.value.custom_response, null) != null ? [default_action.value.custom_response] : []
          content {
            response_code            = custom_response.value.response_code
            custom_response_body_key = try(custom_response.value.custom_response_body_key, null)

            dynamic "response_header" {
              for_each = try(custom_response.value.response_headers, {})
              content {
                name  = response_header.value.name
                value = response_header.value.value
              }
            }
          }
        }

      }
    }
  }

  # Visibility configuration
  visibility_config {
    cloudwatch_metrics_enabled = var.visibility_config.cloudwatch_metrics_enabled
    metric_name                = var.visibility_config.metric_name
    sampled_requests_enabled   = var.visibility_config.sampled_requests_enabled
  }

  # Custom response bodies
  dynamic "custom_response_body" {
    for_each = var.custom_response_bodies
    content {
      key          = custom_response_body.key
      content      = custom_response_body.value.content
      content_type = custom_response_body.value.content_type
    }
  }

  # Managed rule groups from dedicated variable
  dynamic "rule" {
    for_each = local.managed_rule_groups_list
    content {
      name     = rule.value.name
      priority = rule.value.priority

      override_action {
        dynamic "none" {
          for_each = rule.value.rule.override_action == null || rule.value.rule.override_action == "NONE" ? [1] : []
          content {}
        }

        dynamic "count" {
          for_each = rule.value.rule.override_action == "COUNT" ? [1] : []
          content {}
        }
      }

      statement {
        dynamic "managed_rule_group_statement" {
          for_each = rule.value.rule != null ? [rule.value.rule] : []
          content {
            vendor_name = managed_rule_group_statement.value.vendor_name
            name        = managed_rule_group_statement.value.name
            version     = try(managed_rule_group_statement.value.version, null)

            # excluded rules removed to avoid provider schema mismatch

            dynamic "rule_action_override" {
              for_each = managed_rule_group_statement.value.rule_action_overrides != null ? managed_rule_group_statement.value.rule_action_overrides : []
              content {
                name = rule_action_override.value.name

                action_to_use {
                  dynamic "block" {
                    for_each = rule_action_override.value.action_to_use == "BLOCK" ? [1] : []
                    content {}
                  }

                  dynamic "allow" {
                    for_each = rule_action_override.value.action_to_use == "ALLOW" ? [1] : []
                    content {}
                  }

                  dynamic "count" {
                    for_each = rule_action_override.value.action_to_use == "COUNT" ? [1] : []
                    content {}
                  }
                }
              }
            }
          }
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name}-${rule.value.name}"
        sampled_requests_enabled   = true
      }
    }
  }

  # Rate limit rules
  dynamic "rule" {
    for_each = local.rate_limit_rules_list
    content {
      name     = rule.value.name
      priority = rule.value.priority

      dynamic "action" {
        for_each = [rule.value.rule.action]
        content {
          dynamic "block" {
            for_each = action.value == "BLOCK" ? [1] : []
            content {}
          }

          dynamic "allow" {
            for_each = action.value == "ALLOW" ? [1] : []
            content {}
          }

          dynamic "count" {
            for_each = action.value == "COUNT" ? [1] : []
            content {}
          }
        }
      }

      statement {
        rate_based_statement {
          limit              = rule.value.rule.limit
          aggregate_key_type = rule.value.rule.aggregate_key_type
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = rule.value.rule.visibility_config.cloudwatch_metrics_enabled
        metric_name                = rule.value.rule.visibility_config.metric_name
        sampled_requests_enabled   = rule.value.rule.visibility_config.sampled_requests_enabled
      }
    }
  }

  # Geo match rules
  dynamic "rule" {
    for_each = local.geo_match_rules_list
    content {
      name     = rule.value.name
      priority = rule.value.priority

      dynamic "action" {
        for_each = [rule.value.rule.action]
        content {
          dynamic "block" {
            for_each = action.value == "BLOCK" ? [1] : []
            content {}
          }

          dynamic "allow" {
            for_each = action.value == "ALLOW" ? [1] : []
            content {}
          }

          dynamic "count" {
            for_each = action.value == "COUNT" ? [1] : []
            content {}
          }
        }
      }

      statement {
        geo_match_statement {
          country_codes = rule.value.rule.country_codes
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = rule.value.rule.visibility_config.cloudwatch_metrics_enabled
        metric_name                = rule.value.rule.visibility_config.metric_name
        sampled_requests_enabled   = rule.value.rule.visibility_config.sampled_requests_enabled
      }
    }
  }

  # Byte match rules
  dynamic "rule" {
    for_each = local.byte_match_rules_list
    content {
      name     = rule.value.name
      priority = rule.value.priority

      dynamic "action" {
        for_each = [rule.value.rule.action]
        content {
          dynamic "block" {
            for_each = action.value == "BLOCK" ? [1] : []
            content {}
          }

          dynamic "allow" {
            for_each = action.value == "ALLOW" ? [1] : []
            content {}
          }

          dynamic "count" {
            for_each = action.value == "COUNT" ? [1] : []
            content {}
          }
        }
      }

      statement {
        byte_match_statement {
          search_string = rule.value.rule.search_string
          field_to_match {
            dynamic "uri_path" {
              for_each = rule.value.rule.field_to_match == "uri_path" ? [1] : []
              content {}
            }

            dynamic "query_string" {
              for_each = rule.value.rule.field_to_match == "query_string" ? [1] : []
              content {}
            }

            dynamic "body" {
              for_each = rule.value.rule.field_to_match == "body" ? [1] : []
              content {}
            }

            dynamic "single_header" {
              for_each = startswith(rule.value.rule.field_to_match, "header:") ? [1] : []
              content {
                name = replace(rule.value.rule.field_to_match, "header:", "")
              }
            }
          }
          text_transformation {
            priority = 0
            type     = "NONE"
          }
          positional_constraint = rule.value.rule.positional_constraint
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = rule.value.rule.visibility_config.cloudwatch_metrics_enabled
        metric_name                = rule.value.rule.visibility_config.metric_name
        sampled_requests_enabled   = rule.value.rule.visibility_config.sampled_requests_enabled
      }
    }
  }

  # Size constraint rules
  dynamic "rule" {
    for_each = local.size_constraint_rules_list
    content {
      name     = rule.value.name
      priority = rule.value.priority

      dynamic "action" {
        for_each = [rule.value.rule.action]
        content {
          dynamic "block" {
            for_each = action.value == "BLOCK" ? [1] : []
            content {}
          }

          dynamic "allow" {
            for_each = action.value == "ALLOW" ? [1] : []
            content {}
          }

          dynamic "count" {
            for_each = action.value == "COUNT" ? [1] : []
            content {}
          }
        }
      }

      statement {
        size_constraint_statement {
          field_to_match {
            dynamic "uri_path" {
              for_each = rule.value.rule.field_to_match == "uri_path" ? [1] : []
              content {}
            }

            dynamic "query_string" {
              for_each = rule.value.rule.field_to_match == "query_string" ? [1] : []
              content {}
            }

            dynamic "body" {
              for_each = rule.value.rule.field_to_match == "body" ? [1] : []
              content {}
            }

            dynamic "single_header" {
              for_each = startswith(rule.value.rule.field_to_match, "header:") ? [1] : []
              content {
                name = replace(rule.value.rule.field_to_match, "header:", "")
              }
            }
          }
          comparison_operator = rule.value.rule.comparison_operator
          size                = rule.value.rule.size

          dynamic "text_transformation" {
            for_each = rule.value.rule.text_transformation != null ? rule.value.rule.text_transformation : [{ priority = 0, type = "NONE" }]
            content {
              priority = text_transformation.value.priority
              type     = text_transformation.value.type
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = rule.value.rule.visibility_config.cloudwatch_metrics_enabled
        metric_name                = rule.value.rule.visibility_config.metric_name
        sampled_requests_enabled   = rule.value.rule.visibility_config.sampled_requests_enabled
      }
    }
  }

  # SQL injection match rules
  dynamic "rule" {
    for_each = local.sqli_match_rules_list
    content {
      name     = rule.value.name
      priority = rule.value.priority

      dynamic "action" {
        for_each = [rule.value.rule.action]
        content {
          dynamic "block" {
            for_each = action.value == "BLOCK" ? [1] : []
            content {}
          }

          dynamic "allow" {
            for_each = action.value == "ALLOW" ? [1] : []
            content {}
          }

          dynamic "count" {
            for_each = action.value == "COUNT" ? [1] : []
            content {}
          }
        }
      }

      statement {
        sqli_match_statement {

          field_to_match {
            dynamic "uri_path" {
              for_each = try(rule.value.rule.field_to_match.uri_path, null) != null ? [1] : []
              content {}
            }

            dynamic "query_string" {
              for_each = try(rule.value.rule.field_to_match.query_string, null) != null ? [1] : []
              content {}
            }

            dynamic "body" {
              for_each = try(rule.value.rule.field_to_match.body, null) != null ? [1] : []
              content {}
            }

            dynamic "single_header" {
              for_each = try(rule.value.rule.field_to_match.single_header, null) != null ? [rule.value.rule.field_to_match.single_header] : []
              content {
                name = single_header.value.name
              }
            }
          }

          dynamic "text_transformation" {
            for_each = try(rule.value.rule.text_transformation, [])
            content {
              priority = text_transformation.value.priority
              type     = text_transformation.value.type
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = rule.value.rule.visibility_config.cloudwatch_metrics_enabled
        metric_name                = rule.value.rule.visibility_config.metric_name
        sampled_requests_enabled   = rule.value.rule.visibility_config.sampled_requests_enabled
      }
    }
  }

  # XSS match rules
  dynamic "rule" {
    for_each = local.xss_match_rules_list
    content {
      name     = rule.value.name
      priority = rule.value.priority

      dynamic "action" {
        for_each = [rule.value.rule.action]
        content {
          dynamic "block" {
            for_each = action.value == "BLOCK" ? [1] : []
            content {}
          }

          dynamic "allow" {
            for_each = action.value == "ALLOW" ? [1] : []
            content {}
          }

          dynamic "count" {
            for_each = action.value == "COUNT" ? [1] : []
            content {}
          }
        }
      }

      statement {
        xss_match_statement {
          field_to_match {
            dynamic "uri_path" {
              for_each = rule.value.rule.field_to_match == "uri_path" ? [1] : []
              content {}
            }

            dynamic "query_string" {
              for_each = rule.value.rule.field_to_match == "query_string" ? [1] : []
              content {}
            }

            dynamic "body" {
              for_each = rule.value.rule.field_to_match == "body" ? [1] : []
              content {}
            }

            dynamic "single_header" {
              for_each = startswith(rule.value.rule.field_to_match, "header:") ? [1] : []
              content {
                name = replace(rule.value.rule.field_to_match, "header:", "")
              }
            }
          }

          dynamic "text_transformation" {
            for_each = rule.value.rule.text_transformation != null ? rule.value.rule.text_transformation : [{ priority = 0, type = "NONE" }]
            content {
              priority = text_transformation.value.priority
              type     = text_transformation.value.type
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = rule.value.rule.visibility_config.cloudwatch_metrics_enabled
        metric_name                = rule.value.rule.visibility_config.metric_name
        sampled_requests_enabled   = rule.value.rule.visibility_config.sampled_requests_enabled
      }
    }
  }

  # Rules from the dedicated rules variable
  dynamic "rule" {
    for_each = var.rules
    content {
      name     = rule.value.name
      priority = rule.value.priority

      dynamic "action" {
        for_each = [rule.value.action]
        content {
          dynamic "block" {
            for_each = action.value == "BLOCK" ? [1] : []
            content {}
          }

          dynamic "allow" {
            for_each = action.value == "ALLOW" ? [1] : []
            content {}
          }

          dynamic "count" {
            for_each = action.value == "COUNT" ? [1] : []
            content {}
          }
        }
      }

      statement {
        dynamic "managed_rule_group_statement" {
          for_each = rule.value.managed_rule_group_statement != null ? [rule.value.managed_rule_group_statement] : []
          content {
            vendor_name = managed_rule_group_statement.value.vendor_name
            name        = managed_rule_group_statement.value.name
            version     = managed_rule_group_statement.value.version

              # excluded rules removed to avoid provider schema mismatch

            dynamic "rule_action_override" {
              for_each = managed_rule_group_statement.value.rule_action_overrides != null ? managed_rule_group_statement.value.rule_action_overrides : []
              content {
                name = rule_action_override.value.name

                action_to_use {
                  dynamic "block" {
                    for_each = rule_action_override.value.action_to_use == "BLOCK" ? [1] : []
                    content {}
                  }

                  dynamic "allow" {
                    for_each = rule_action_override.value.action_to_use == "ALLOW" ? [1] : []
                    content {}
                  }

                  dynamic "count" {
                    for_each = rule_action_override.value.action_to_use == "COUNT" ? [1] : []
                    content {}
                  }
                }
              }
            }
          }
        }

        dynamic "rate_based_statement" {
          for_each = rule.value.rate_limit_statement != null ? [rule.value.rate_limit_statement] : []
          content {
            limit              = rate_based_statement.value.limit
            aggregate_key_type = rate_based_statement.value.aggregate_key_type
          }
        }

        dynamic "ip_set_reference_statement" {
          for_each = rule.value.ip_set_reference_statement != null ? [rule.value.ip_set_reference_statement] : []
          content {
            arn = ip_set_reference_statement.value.arn
          }
        }

        dynamic "regex_pattern_set_reference_statement" {
          for_each = rule.value.regex_pattern_set_reference_statement != null ? [rule.value.regex_pattern_set_reference_statement] : []
          content {
            arn = regex_pattern_set_reference_statement.value.arn

            field_to_match {
              dynamic "single_header" {
                for_each = regex_pattern_set_reference_statement.value.field_to_match.single_header != null ? [regex_pattern_set_reference_statement.value.field_to_match.single_header] : []
                content {
                  name = single_header.value.name
                }
              }

              dynamic "uri_path" {
                for_each = regex_pattern_set_reference_statement.value.field_to_match.uri_path != null ? [1] : []
                content {}
              }

              dynamic "query_string" {
                for_each = regex_pattern_set_reference_statement.value.field_to_match.query_string != null ? [1] : []
                content {}
              }

              dynamic "body" {
                for_each = regex_pattern_set_reference_statement.value.field_to_match.body != null ? [1] : []
                content {}
              }
            }

            dynamic "text_transformation" {
              for_each = regex_pattern_set_reference_statement.value.text_transformation
              content {
                priority = text_transformation.value.priority
                type     = text_transformation.value.type
              }
            }
          }
        }

        dynamic "byte_match_statement" {
          for_each = rule.value.byte_match_statement != null ? [rule.value.byte_match_statement] : []
          content {
            positional_constraint = byte_match_statement.value.positional_constraint
            search_string         = byte_match_statement.value.search_string

            field_to_match {
              dynamic "single_header" {
                for_each = byte_match_statement.value.field_to_match.single_header != null ? [byte_match_statement.value.field_to_match.single_header] : []
                content {
                  name = single_header.value.name
                }
              }

              dynamic "uri_path" {
                for_each = byte_match_statement.value.field_to_match.uri_path != null ? [1] : []
                content {}
              }

              dynamic "query_string" {
                for_each = byte_match_statement.value.field_to_match.query_string != null ? [1] : []
                content {}
              }

              dynamic "body" {
                for_each = byte_match_statement.value.field_to_match.body != null ? [1] : []
                content {}
              }
            }

            dynamic "text_transformation" {
              for_each = byte_match_statement.value.text_transformation
              content {
                priority = text_transformation.value.priority
                type     = text_transformation.value.type
              }
            }
          }
        }

        dynamic "size_constraint_statement" {
          for_each = rule.value.size_constraint_statement != null ? [rule.value.size_constraint_statement] : []
          content {
            comparison_operator = size_constraint_statement.value.comparison_operator
            size                = size_constraint_statement.value.size

            field_to_match {
              dynamic "single_header" {
                for_each = size_constraint_statement.value.field_to_match.single_header != null ? [size_constraint_statement.value.field_to_match.single_header] : []
                content {
                  name = single_header.value.name
                }
              }

              dynamic "uri_path" {
                for_each = size_constraint_statement.value.field_to_match.uri_path != null ? [1] : []
                content {}
              }

              dynamic "query_string" {
                for_each = size_constraint_statement.value.field_to_match.query_string != null ? [1] : []
                content {}
              }

              dynamic "body" {
                for_each = size_constraint_statement.value.field_to_match.body != null ? [1] : []
                content {}
              }
            }

            dynamic "text_transformation" {
              for_each = size_constraint_statement.value.text_transformation != null ? size_constraint_statement.value.text_transformation : []
              content {
                priority = text_transformation.value.priority
                type     = text_transformation.value.type
              }
            }
          }
        }

        dynamic "sqli_injection_match_statement" {
          for_each = rule.value.sqli_match_statement != null ? [rule.value.sqli_match_statement] : []
          content {
            field_to_match {
              dynamic "single_header" {
                for_each = sqli_injection_match_statement.value.field_to_match.single_header != null ? [sqli_injection_match_statement.value.field_to_match.single_header] : []
                content {
                  name = single_header.value.name
                }
              }

              dynamic "uri_path" {
                for_each = sqli_injection_match_statement.value.field_to_match.uri_path != null ? [1] : []
                content {}
              }

              dynamic "query_string" {
                for_each = sqli_injection_match_statement.value.field_to_match.query_string != null ? [1] : []
                content {}
              }

              dynamic "body" {
                for_each = sqli_injection_match_statement.value.field_to_match.body != null ? [1] : []
                content {}
              }
            }

            dynamic "text_transformation" {
              for_each = sqli_injection_match_statement.value.text_transformation != null ? sqli_injection_match_statement.value.text_transformation : []
              content {
                priority = text_transformation.value.priority
                type     = text_transformation.value.type
              }
            }
          }
        }

        dynamic "xss_match_statement" {
          for_each = rule.value.xss_match_statement != null ? [rule.value.xss_match_statement] : []
          content {
            field_to_match {
              dynamic "single_header" {
                for_each = xss_match_statement.value.field_to_match.single_header != null ? [xss_match_statement.value.field_to_match.single_header] : []
                content {
                  name = single_header.value.name
                }
              }

              dynamic "uri_path" {
                for_each = xss_match_statement.value.field_to_match.uri_path != null ? [1] : []
                content {}
              }

              dynamic "query_string" {
                for_each = xss_match_statement.value.field_to_match.query_string != null ? [1] : []
                content {}
              }

              dynamic "body" {
                for_each = xss_match_statement.value.field_to_match.body != null ? [1] : []
                content {}
              }
            }

            dynamic "text_transformation" {
              for_each = xss_match_statement.value.text_transformation != null ? xss_match_statement.value.text_transformation : []
              content {
                priority = text_transformation.value.priority
                type     = text_transformation.value.type
              }
            }
          }
        }

        dynamic "geo_match_statement" {
          for_each = rule.value.geo_match_statement != null ? [rule.value.geo_match_statement] : []
          content {
            country_codes = geo_match_statement.value.country_codes
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = rule.value.visibility_config.cloudwatch_metrics_enabled
        metric_name                = rule.value.visibility_config.metric_name
        sampled_requests_enabled   = rule.value.visibility_config.sampled_requests_enabled
      }
    }
  }

  tags = var.tags

  depends_on = [
    aws_wafv2_ip_set.this,
    aws_wafv2_regex_pattern_set.this
  ]
}

# Web ACL Associations
resource "aws_wafv2_web_acl_association" "this" {
  for_each = toset(var.association_resource_arns)

  resource_arn = each.value
  web_acl_arn  = aws_wafv2_web_acl.this.arn

  depends_on = [aws_wafv2_web_acl.this]
}
