module "wafv2" {
  source = "./modules/wafv2"

  name                        = var.name
  description                 = var.description
  scope                       = var.scope
  default_action              = var.default_action
  rules                       = var.rules
  visibility_config           = var.visibility_config
  tags                        = var.tags
  ip_set_references           = var.ip_set_references
  regex_pattern_sets          = var.regex_pattern_sets
  managed_rule_groups         = var.managed_rule_groups
  custom_response_bodies      = var.custom_response_bodies
  logging_configuration       = var.logging_configuration
  association_resource_arns   = var.association_resource_arns
  rate_limit_rules            = var.rate_limit_rules
  geo_match_rules             = var.geo_match_rules
  byte_match_rules            = var.byte_match_rules
  size_constraint_rules       = var.size_constraint_rules
  sqli_match_rules            = var.sqli_match_rules
  xss_match_rules             = var.xss_match_rules
}
