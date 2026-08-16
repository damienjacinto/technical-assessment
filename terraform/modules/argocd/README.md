<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | ~> 2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | n/a |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | ~> 2.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.argocd](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.app_of_apps](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alb_security_group_id"></a> [alb\_security\_group\_id](#input\_alb\_security\_group\_id) | Security group restricting this Ingress's ALB to the allowlisted IPs, e.g. local.foundation.alb\_ip\_restricted\_sg\_id via foundation's remote state. This is this Ingress's actual access control -- no WAF in front of it. | `string` | n/a | yes |
| <a name="input_argo_app_labels"></a> [argo\_app\_labels](#input\_argo\_app\_labels) | Labels applied to the root app-of-apps Application. | `map(string)` | `{}` | no |
| <a name="input_argocd_chart_version"></a> [argocd\_chart\_version](#input\_argocd\_chart\_version) | argo-cd Helm chart version to install. | `string` | `"10.3.3"` | no |
| <a name="input_git_repo_url"></a> [git\_repo\_url](#input\_git\_repo\_url) | This repo's git URL, as ArgoCD Applications' source.repoURL. | `string` | n/a | yes |
| <a name="input_git_revision"></a> [git\_revision](#input\_git\_revision) | Git revision (branch/tag) ArgoCD Applications track as source.targetRevision. | `string` | `"main"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_argocd_namespace"></a> [argocd\_namespace](#output\_argocd\_namespace) | Kubernetes namespace ArgoCD is installed into. |
<!-- END_TF_DOCS -->
