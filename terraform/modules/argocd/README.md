<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | n/a |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.argocd](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_manifest.infra_app](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.the_redemption](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_argo_app_labels"></a> [argo\_app\_labels](#input\_argo\_app\_labels) | Labels applied to every ArgoCD Application this module creates. | `map(string)` | `{}` | no |
| <a name="input_argocd_chart_version"></a> [argocd\_chart\_version](#input\_argocd\_chart\_version) | argo-cd Helm chart version to install. | `string` | `"7.7.11"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name, threaded into the-redemption's Application as a Helm value. | `string` | n/a | yes |
| <a name="input_git_repo_url"></a> [git\_repo\_url](#input\_git\_repo\_url) | This repo's git URL, as ArgoCD Applications' source.repoURL. | `string` | n/a | yes |
| <a name="input_git_revision"></a> [git\_revision](#input\_git\_revision) | Git revision (branch/tag) ArgoCD Applications track as source.targetRevision. | `string` | `"main"` | no |
| <a name="input_waf_web_acl_arn"></a> [waf\_web\_acl\_arn](#input\_waf\_web\_acl\_arn) | From the security-baseline module, wired into the-redemption's Ingress annotation. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_argocd_namespace"></a> [argocd\_namespace](#output\_argocd\_namespace) | Kubernetes namespace ArgoCD is installed into. |
<!-- END_TF_DOCS -->
