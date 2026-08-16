# Karpenter, split by concern: iam.tf, sqs.tf, security_group.tf, this
# file, nodepools.tf. NodePool/EC2NodeClass live in Terraform, not
# GitOps, to break a deadlock: ArgoCD needs a Karpenter-provisioned node.

resource "helm_release" "karpenter_crd" {
  name             = "karpenter-crd"
  namespace        = "kube-system"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter-crd"
  version          = var.karpenter_chart_version
  create_namespace = false
  max_history      = 5
  force_update     = false
  recreate_pods    = true
  wait             = true
}

resource "helm_release" "karpenter" {
  name             = "karpenter"
  namespace        = "kube-system"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = var.karpenter_chart_version
  create_namespace = false
  max_history      = 5
  force_update     = false
  recreate_pods    = true
  wait             = true

  # Both deps matter: the SecurityGroupPolicy must exist before the first
  # pod (SGs-for-Pods assigns at pod creation, not retroactively), and the
  # CRDs must be current before the controller starts.
  depends_on = [kubectl_manifest.controller_security_group_policy, helm_release.karpenter_crd]

  values = [
    yamlencode({
      # IRSA (not Pod Identity, see iam.tf) needs this annotation.
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.controller.arn
        }
      }
      settings = {
        clusterName       = var.cluster_name
        clusterEndpoint   = var.cluster_endpoint
        interruptionQueue = aws_sqs_queue.interruption.name
      }
      nodeSelector = {
        "eks.amazonaws.com/compute-type" = "fargate"
      }
    })
  ]
}
