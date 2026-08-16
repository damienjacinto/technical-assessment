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
      # No affinity override here -- Fargate eligibility is governed at
      # the source, by the kube-system Fargate profile's own selectors
      # (terraform/modules/fargate-profile/main.tf), which only match
      # k8s-app=kube-dns and app.kubernetes.io/name=karpenter. This
      # controller's labels match neither, so it's never Fargate-eligible
      # to begin with -- one precise selector to keep in sync, not a
      # per-controller exclusion re-added on every chart that shouldn't
      # run there. The chart's own configureDefaultAffinity default
      # (podAntiAffinity spreading replicas across nodes) is left alone.
    })
  ]
}
