<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eks"></a> [eks](#module\_eks) | terraform-aws-modules/eks/aws | ~> 21.0 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_enabled_log_types"></a> [cluster\_enabled\_log\_types](#input\_cluster\_enabled\_log\_types) | Control plane log types shipped to CloudWatch Logs. Default is all five EKS supports. | `list(string)` | <pre>[<br/>  "api",<br/>  "audit",<br/>  "authenticator",<br/>  "controllerManager",<br/>  "scheduler"<br/>]</pre> | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | EKS cluster name, e.g. "redemption-prod-eks". | `string` | n/a | yes |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | Kubernetes version for the control plane. Versioning policy (see<br/>docs/ARCHITECTURE.md): track "latest minus one" EKS-supported minor<br/>version, not the newest release -- current is 1.36 (GA June 2026), so<br/>the default here is 1.35, not 1.36. Only jump to the newest minor if a<br/>specific feature it introduces is actually needed; otherwise staying<br/>one behind means the version has had a few months of the rest of the<br/>ecosystem (controllers, Helm charts, this team's own tooling) catching<br/>up to it before this cluster runs it. | `string` | `"1.35"` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | n/a | `string` | n/a | yes |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | Private subnet IDs the control plane ENIs and (indirectly, via Karpenter) worker nodes live in. | `list(string)` | n/a | yes |
| <a name="input_public_endpoint_allowed_cidrs"></a> [public\_endpoint\_allowed\_cidrs](#input\_public\_endpoint\_allowed\_cidrs) | CIDRs allowed to reach the public API endpoint -- least privilege, never 0.0.0.0/0 for a revenue-critical cluster. | `list(string)` | n/a | yes |
| <a name="input_public_endpoint_enabled"></a> [public\_endpoint\_enabled](#input\_public\_endpoint\_enabled) | Whether the EKS API server's public endpoint is enabled at all. Private access is always on regardless. | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | n/a | `map(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | n/a | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | n/a |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | n/a |
| <a name="output_cluster_iam_role_arn"></a> [cluster\_iam\_role\_arn](#output\_cluster\_iam\_role\_arn) | n/a |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | n/a |
| <a name="output_cluster_security_group_id"></a> [cluster\_security\_group\_id](#output\_cluster\_security\_group\_id) | n/a |
| <a name="output_cluster_version"></a> [cluster\_version](#output\_cluster\_version) | n/a |
| <a name="output_secrets_kms_key_arn"></a> [secrets\_kms\_key\_arn](#output\_secrets\_kms\_key\_arn) | n/a |
<!-- END_TF_DOCS -->
