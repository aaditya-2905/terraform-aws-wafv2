variable "region" {
  description = "AWS region for the WAF resources"
  type        = string
}

variable "name" {
  description = "Name of the Web ACL"
  type        = string
}

variable "description" {
  description = "Description of the Web ACL"
  type        = string
  default     = ""
}

variable "scope" {
  description = "Scope of the Web ACL (REGIONAL or CLOUDFRONT)"
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = contains(["REGIONAL", "CLOUDFRONT"], var.scope)
    error_message = "Scope must be either REGIONAL or CLOUDFRONT."
  }
}

variable "default_action" {
  description = "Default action for the Web ACL"
  type = object({
    allow = optional(object(
      {
        custom_response = optional(object({
          custom_response_body_key = optional(string)
          response_code            = number
          response_headers = optional(map(object({
            name  = string
            value = string
          })))
        }))
      }
    ))
    block = optional(object(
      {
        custom_response = optional(object({
          custom_response_body_key = optional(string)
          response_code            = number
          response_headers = optional(map(object({
            name  = string
            value = string
          })))
        }))
      }
    ))
  })
  default = {
    allow = {}
  }
}

variable "rules" {
  description = "List of rules for the Web ACL"
  type = list(object({
    name            = string
    priority        = number
    action          = optional(string, "BLOCK") # BLOCK or ALLOW or COUNT
    override_action = optional(string)            # For managed rule groups

    # Statement types
    managed_rule_group_statement = optional(object({
      vendor_name            = string
      name                   = string
      version                = optional(string)
      rule_action_overrides  = optional(list(object({
        name          = string
        action_to_use = string
      })))
      scope_down_statement = optional(any)
    }))

    rate_limit_statement = optional(object({
      limit              = number
      aggregate_key_type = optional(string, "IP")
      scope_down_statement = optional(any)
    }))

    ip_set_reference_statement = optional(object({
      arn = string
    }))

    regex_pattern_set_reference_statement = optional(object({
      arn = string
      field_to_match = object({
        single_header = optional(object({
          name = string
        }))
        uri_path = optional(object({}))
        query_string = optional(object({}))
        body = optional(object({}))
      })
      text_transformation = list(object({
        priority = number
        type     = string
      }))
    }))

    byte_match_statement = optional(object({
      field_to_match = object({
        single_header = optional(object({
          name = string
        }))
        uri_path = optional(object({}))
        query_string = optional(object({}))
        body = optional(object({}))
      })
      positional_constraint = string
      search_string        = string
      text_transformation = list(object({
        priority = number
        type     = string
      }))
    }))

    size_constraint_statement = optional(object({
      field_to_match = object({
        single_header = optional(object({
          name = string
        }))
        uri_path = optional(object({}))
        query_string = optional(object({}))
        body = optional(object({}))
      })
      comparison_operator = string
      size                = number
      text_transformation = optional(list(object({
        priority = number
        type     = string
      })))
    }))

    sqli_match_statement = optional(object({
      field_to_match = object({
        single_header = optional(object({
          name = string
        }))
        uri_path = optional(object({}))
        query_string = optional(object({}))
        body = optional(object({}))
      })
      text_transformation = optional(list(object({
        priority = number
        type     = string
      })))
    }))

    xss_match_statement = optional(object({
      field_to_match = object({
        single_header = optional(object({
          name = string
        }))
        uri_path = optional(object({}))
        query_string = optional(object({}))
        body = optional(object({}))
      })
      text_transformation = optional(list(object({
        priority = number
        type     = string
      })))
    }))

    geo_match_statement = optional(object({
      country_codes = list(string)
    }))

    visibility_config = object({
      cloudwatch_metrics_enabled = optional(bool, true)
      metric_name                = string
      sampled_requests_enabled   = optional(bool, true)
    })

    action_override = optional(object({
      custom_request_body_key = optional(string)
      none                    = optional(object({}))
    }))
  }))
  default = []
}

variable "visibility_config" {
  description = "Visibility config for the Web ACL"
  type = object({
    cloudwatch_metrics_enabled = optional(bool, true)
    metric_name                = string
    sampled_requests_enabled   = optional(bool, true)
  })
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "ip_set_references" {
  description = "Map of IP sets to create"
  type = map(object({
    scope              = string
    address_definition = list(string)
    description        = optional(string)
    tags               = optional(map(string), {})
  }))
  default = {}
}

variable "regex_pattern_sets" {
  description = "Map of regex pattern sets to create"
  type = map(object({
    scope            = string
    regular_expressions = list(object({
      regex_string = string
    }))
    description = optional(string)
    tags        = optional(map(string), {})
  }))
  default = {}
}

variable "managed_rule_groups" {
  description = "List of managed rule groups to use"
  type = list(object({
    vendor_name            = string
    name                   = string
    version                = optional(string)
    rule_action_overrides  = optional(list(object({
      name          = string
      action_to_use = string
    })), [])
  }))
  default = []
}

variable "custom_response_bodies" {
  description = "Map of custom response bodies"
  type = map(object({
    content      = string
    content_type = string
  }))
  default = {}
}

variable "logging_configuration" {
  description = "Logging configuration for the Web ACL"
  type = object({
    cloudwatch_logs_log_group = optional(string)
    kinesis_firehose_stream_arn = optional(string)
    s3_bucket                 = optional(string)
    s3_prefix                 = optional(string)
    logging_filter = optional(list(object({
      default_behavior = string
      filters = list(object({
        behavior    = string
        requirement = string
        condition = list(object({
          action_condition = optional(object({
            action = string
          }))
          label_name_condition = optional(object({
            label_name = string
          }))
        }))
      }))
    })))
  })
  default = {}
}

variable "association_resource_arns" {
  description = "List of resource ARNs to associate with the Web ACL (ALB, CloudFront, API Gateway)"
  type        = list(string)
  default     = []
}

variable "rate_limit_rules" {
  description = "List of rate limit rules (can also be specified in rules list)"
  type = list(object({
    name           = string
    priority       = number
    limit          = number
    aggregate_key_type = optional(string, "IP")
    action         = optional(string, "BLOCK")
    visibility_config = object({
      cloudwatch_metrics_enabled = optional(bool, true)
      metric_name                = string
      sampled_requests_enabled   = optional(bool, true)
    })
  }))
  default = []
}

variable "geo_match_rules" {
  description = "List of geo match rules (can also be specified in rules list)"
  type = list(object({
    name              = string
    priority          = number
    country_codes     = list(string)
    action            = optional(string, "BLOCK")
    visibility_config = object({
      cloudwatch_metrics_enabled = optional(bool, true)
      metric_name                = string
      sampled_requests_enabled   = optional(bool, true)
    })
  }))
  default = []
}

variable "byte_match_rules" {
  description = "List of byte match rules (can also be specified in rules list)"
  type = list(object({
    name                = string
    priority            = number
    field_to_match      = string
    positional_constraint = string
    search_string       = string
    action              = optional(string, "BLOCK")
    visibility_config = object({
      cloudwatch_metrics_enabled = optional(bool, true)
      metric_name                = string
      sampled_requests_enabled   = optional(bool, true)
    })
  }))
  default = []
}

variable "size_constraint_rules" {
  description = "List of size constraint rules"
  type = list(object({
    name                = string
    priority            = number
    field_to_match      = string
    comparison_operator = string
    size                = number
    action              = optional(string, "BLOCK")
    visibility_config = object({
      cloudwatch_metrics_enabled = optional(bool, true)
      metric_name                = string
      sampled_requests_enabled   = optional(bool, true)
    })
  }))
  default = []
}

variable "sqli_match_rules" {
  description = "List of SQL injection match rules"
  type = list(object({
    name              = string
    priority          = number
    field_to_match    = string
    action            = optional(string, "BLOCK")
    visibility_config = object({
      cloudwatch_metrics_enabled = optional(bool, true)
      metric_name                = string
      sampled_requests_enabled   = optional(bool, true)
    })
  }))
  default = []
}

variable "xss_match_rules" {
  description = "List of XSS match rules"
  type = list(object({
    name              = string
    priority          = number
    field_to_match    = string
    action            = optional(string, "BLOCK")
    visibility_config = object({
      cloudwatch_metrics_enabled = optional(bool, true)
      metric_name                = string
      sampled_requests_enabled   = optional(bool, true)
    })
  }))
  default = []
}
