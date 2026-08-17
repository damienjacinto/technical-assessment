<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_http"></a> [http](#requirement\_http) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_http"></a> [http](#provider\_http) | ~> 3.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eks"></a> [eks](#module\_eks) | terraform-aws-modules/eks/aws | ~> 21.0 |

## Resources

| Name | Type |
|------|------|
| [http_http.my_ip](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_admin_principal_arns"></a> [additional\_admin\_principal\_arns](#input\_additional\_admin\_principal\_arns) | Extra IAM principal ARNs (users or roles) to grant cluster-admin access via EKS Access Entries | `list(string)` | `[]` | no |
| <a name="input_addon_versions"></a> [addon\_versions](#input\_addon\_versions) | Explicit version to pin per EKS addon (key = addon name: vpc-cni, kube-proxy, eks-pod-identity-agent, metrics-server). An addon left out of this map falls back to most\_recent, which re-resolves on every plan and diffs whenever AWS ships a new build -- pin it here once you've captured the currently-applied version to make plans deterministic. | `map(string)` | `{}` | no |
| <a name="input_cluster_enabled_log_types"></a> [cluster\_enabled\_log\_types](#input\_cluster\_enabled\_log\_types) | Control plane log types shipped to CloudWatch Logs. Default is all five EKS supports. | `list(string)` | <pre>[<br/>  "api",<br/>  "audit",<br/>  "authenticator",<br/>  "controllerManager",<br/>  "scheduler"<br/>]</pre> | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | EKS cluster name, e.g. "redemption-prod-eks". | `string` | n/a | yes |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | Kubernetes version for the control plane. Versioning policy: latest-minus-one, not bleeding edge -- see docs/ARCHITECTURE.md. | `string` | `"1.35"` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix used to name resources created by this module. | `string` | n/a | yes |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | Private subnet IDs the control plane ENIs and (indirectly, via Karpenter) worker nodes live in. | `list(string)` | n/a | yes |
| <a name="input_public_endpoint_allowed_cidrs"></a> [public\_endpoint\_allowed\_cidrs](#input\_public\_endpoint\_allowed\_cidrs) | CIDRs allowed to reach the public API endpoint -- real, internet-routable ranges only (office/VPN/CI runner), never 0.0.0.0/0. | `list(string)` | `[]` | no |
| <a name="input_public_endpoint_enabled"></a> [public\_endpoint\_enabled](#input\_public\_endpoint\_enabled) | Whether the EKS API server's public endpoint is enabled at all. Private access is always on regardless. | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to all resources created by this module. | `map(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC the EKS control plane ENIs are created in. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | Base64-encoded certificate authority data for the EKS cluster. |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | API server endpoint of the EKS cluster. |
| <a name="output_cluster_iam_role_arn"></a> [cluster\_iam\_role\_arn](#output\_cluster\_iam\_role\_arn) | IAM role ARN assumed by the EKS control plane. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the EKS cluster. |
| <a name="output_cluster_security_group_id"></a> [cluster\_security\_group\_id](#output\_cluster\_security\_group\_id) | The EKS-managed cluster security group (what Fargate attaches to pods<br/>by default, and what a custom SecurityGroupPolicy's groupIds must also<br/>include alongside its own SG -- see modules/coredns and<br/>modules/karpenter). Deliberately module.eks.cluster\_primary\_security\_group\_id<br/>here, NOT the confusingly-similarly-named module.eks.cluster\_security\_group\_id<br/>-- that one is a different, module-created additional security group<br/>(aws\_security\_group.cluster in the upstream module), not the actual<br/>EKS-managed cluster SG. Wiring the wrong one silently produces a valid<br/>but useless SecurityGroupPolicy: it stays two-entries "fixed"-looking<br/>while pods still get stuck in an endless Fargate provisioning-timeout<br/>loop, since the SG that's actually missing is still missing. |
| <a name="output_cluster_version"></a> [cluster\_version](#output\_cluster\_version) | Kubernetes version running on the EKS control plane. |
| <a name="output_oidc_provider"></a> [oidc\_provider](#output\_oidc\_provider) | Cluster OIDC issuer, without the https:// prefix -- the condition-key prefix ("<this>:sub", "<this>:aud") an IRSA trust policy's StringEquals conditions need. |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | ARN of the cluster's OIDC identity provider -- the Federated principal an IRSA trust policy needs. Only Karpenter's controller uses this (see modules/karpenter/main.tf); everything else uses Pod Identity. |
| <a name="output_secrets_kms_key_arn"></a> [secrets\_kms\_key\_arn](#output\_secrets\_kms\_key\_arn) | ARN of the KMS key used for Kubernetes Secrets envelope encryption. |
<!-- END_TF_DOCS -->
