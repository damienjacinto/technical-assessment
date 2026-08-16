##############################################################################
# Karpenter. Split by concern: iam.tf (controller IRSA role, node role),
# sqs.tf (interruption handling), security_group.tf (Security Groups for
# Pods), helm.tf (the controller release), nodepools.tf (EC2NodeClass +
# NodePools).
#
# NodePool/EC2NodeClass are created in Terraform, not GitOps, to break a
# bootstrap deadlock: ArgoCD's pods need a Karpenter-provisioned node
# (they're not Fargate-eligible), but Karpenter can't provision anything
# without a NodePool, and a NodePool synced by ArgoCD can't exist until
# ArgoCD is already running. Creating it here breaks the cycle. Trade-off:
# NodePool tuning needs a `terraform apply`, not a GitOps commit, and these
# resources skip kubeconform's schema validation -- terraform validate
# doesn't check K8s CRD schemas, so typos surface at apply time, not CI.
##############################################################################

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
