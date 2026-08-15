##############################################################################
# Security baseline: a general-purpose KMS key (Secrets Manager, EBS -- the
# EKS Secrets envelope-encryption key is self-managed by the eks module
# instead, see that module's main.tf for why), the edge WAFv2 WebACL, and
# the app's baseline Security-Group-for-Pods.
##############################################################################

resource "aws_kms_key" "general" {
  description             = "${var.name_prefix} general-purpose encryption (Secrets Manager, EBS)"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = merge(var.tags, { Name = "${var.name_prefix}-general-kms" })
}

resource "aws_kms_alias" "general" {
  name          = "alias/${var.name_prefix}-general"
  target_key_id = aws_kms_key.general.key_id
}

##############################################################################
# WAFv2 WebACL, associated with the-redemption's ALB via the Ingress's
# alb.ingress.kubernetes.io/wafv2-acl-arn annotation (the ALB itself is
# created by the AWS Load Balancer Controller at runtime, not Terraform, so
# association happens there rather than here).
##############################################################################

resource "aws_wafv2_web_acl" "edge" {
  name = "${var.name_prefix}-edge-waf"
  # WAFv2 description has a restrictive validation pattern (no apostrophes) --
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

# WAF logging -- without this, the rate-based/managed-rule blocks above are
# a black box: no record of what actually got blocked or why, which matters
# both for tuning the rate limit against real flash-sale traffic and for
# incident investigation. Destination log group name MUST start with
# "aws-waf-logs-" -- an AWS API requirement, not a naming preference.
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

##############################################################################
# Baseline Security-Group-for-Pods for the-redemption. Ingress is scoped to
# the VPC CIDR + app port rather than a specific referenced security group
# -- this module intentionally has no dependency on the eks module's
# outputs (the eks module already depends on this one's sibling, and a
# mutual dependency isn't worth introducing for one SG rule). The finer-grained,
# pod-identity-aware restriction is the NetworkPolicy applied at the
# Kubernetes layer (kubernetes/apps/the-redemption/templates/networkpolicy.yaml);
# this SG is the coarser network-layer backstop underneath it -- defense in
# depth is multiple layers, not one layer trying to do everything.
##############################################################################

resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-the-redemption-sg"
  description = "the-redemption app pods (Security Groups for Pods)"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-the-redemption-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "app_from_vpc" {
  security_group_id = aws_security_group.app.id
  description       = "From within the VPC (ALB target group, in-cluster) on the app port"
  cidr_ipv4         = var.vpc_cidr
  from_port         = var.app_port
  to_port           = var.app_port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_to_vpc" {
  security_group_id = aws_security_group.app.id
  description       = "To the rest of the VPC (database tier, in-cluster services)"
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "app_https_out" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS -- AWS API calls via the VPC interface endpoints"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}
