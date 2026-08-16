# Associated with the-redemption's ALB via the Ingress's
# alb.ingress.kubernetes.io/wafv2-acl-arn annotation (the ALB itself is
# created by the AWS Load Balancer Controller at runtime, not Terraform, so
# association happens there rather than here).
resource "aws_wafv2_web_acl" "edge" {
  name = "${var.name_prefix}-edge-waf"
  # No apostrophes: WAFv2's description validation pattern rejects them --
  # caught by tflint's aws_wafv2_web_acl_invalid_description rule, which
  # would otherwise have surfaced as an apply-time API error instead.
  description = "Edge WAF for the-redemption ALB: AWS managed rule groups + a rate-based rule"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 0
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-common-rule-set"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 2
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-sqli"
      sampled_requests_enabled   = true
    }
  }

  # Deliberately generous: a flash sale is legitimately spiky traffic from
  # real customers. This catches per-IP abuse (credential stuffing, scraping)
  # without punishing the traffic pattern this whole design exists to serve.
  rule {
    name     = "RateBasedAbuseProtection"
    priority = 3
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = var.rate_limit_per_5min
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-rate-based-abuse"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-edge-waf"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "waf" {
  name = "aws-waf-logs-${var.name_prefix}-edge"
  # 1 year: security-relevant audit trail, not routine app logging -- kept
  # long enough to investigate an incident discovered well after the fact.
  retention_in_days = 365
  kms_key_id        = aws_kms_key.general.arn
  tags              = var.tags
}

resource "aws_wafv2_web_acl_logging_configuration" "edge" {
  resource_arn            = aws_wafv2_web_acl.edge.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
}
