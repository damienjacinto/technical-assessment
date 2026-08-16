##############################################################################
# AWS Load Balancer Controller: Pod Identity role + Helm release. Creates
# the ALB and target groups at runtime when an Ingress is applied (not
# Terraform) -- its Helm values carry --default-tags so those runtime-created
# resources still inherit this stack's tag taxonomy (see NOTES.md).
##############################################################################

resource "helm_release" "alb_controller" {
  name          = "aws-load-balancer-controller"
  namespace     = "kube-system"
  repository    = "https://aws.github.io/eks-charts"
  chart         = "aws-load-balancer-controller"
  version       = var.chart_version
  max_history   = 5
  force_update  = false
  recreate_pods = true
  wait          = true

  values = [
    yamlencode({
      clusterName = var.cluster_name
      serviceAccount = {
        create = true
        name   = "aws-load-balancer-controller"
      }
      vpcId       = var.vpc_id
      region      = var.aws_region
      defaultTags = var.tags
      nodeSelector = {
        "karpenter.sh/nodepool" = "tools"
      }
      tolerations = [
        {
          key      = "dedicated"
          operator = "Equal"
          value    = "tools"
          effect   = "NoSchedule"
        }
      ]
    })
  ]
}
