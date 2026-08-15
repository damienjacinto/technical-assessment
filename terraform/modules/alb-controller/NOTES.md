# IAM policy: reconcile before applying

`data.aws_iam_policy_document.alb_controller` in this module is a representative
reproduction of the AWS Load Balancer Controller's official IAM policy, written from
memory of its well-known structure -- not a byte-for-byte copy.

Before applying this to a real account, diff it against the canonical, versioned source:

    https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

The controller project updates this policy as it gains features; an IAM policy is
security-sensitive enough that "close enough from memory" isn't the bar for what
actually gets applied.
