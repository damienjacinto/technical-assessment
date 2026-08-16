# Spot interruption / rebalance-recommendation events Karpenter consumes to
# cordon and reschedule proactively instead of reacting to a bare eviction.
resource "aws_sqs_queue" "interruption" {
  name                      = "${var.name_prefix}-karpenter-interruption"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true
  tags                      = var.tags
}

resource "aws_sqs_queue_policy" "interruption" {
  queue_url = aws_sqs_queue.interruption.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowEventBridgeAndSpotServiceToSendMessages"
        Effect    = "Allow"
        Principal = { Service = ["events.amazonaws.com", "sqs.amazonaws.com"] }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.interruption.arn
      }
    ]
  })
}

resource "aws_cloudwatch_event_rule" "spot_interruption" {
  name = "${var.name_prefix}-karpenter-spot-interruption"
  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "spot_interruption" {
  rule = aws_cloudwatch_event_rule.spot_interruption.name
  arn  = aws_sqs_queue.interruption.arn
}

resource "aws_cloudwatch_event_rule" "rebalance_recommendation" {
  name = "${var.name_prefix}-karpenter-rebalance"
  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "rebalance_recommendation" {
  rule = aws_cloudwatch_event_rule.rebalance_recommendation.name
  arn  = aws_sqs_queue.interruption.arn
}
