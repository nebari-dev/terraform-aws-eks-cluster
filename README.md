# terraform-aws-eks-cluster

## Module Documentation

The following section contains auto-generated documentation for this Terraform module using terraform-docs:

<!-- BEGIN_TF_DOCS -->


## Usage

```hcl
module "cluster" {
  source = "github.com/nebari-dev/terraform-aws-eks-cluster"

  project_name = "eks-cluster"

  # VPC configuration
  create_vpc         = true
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
  vpc_cidr_block     = "10.10.0.0/16"

  # Cluster configuration
  kubernetes_version        = "1.34"
  endpoint_private_access   = true
  endpoint_public_access    = true
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  node_groups = {
    general = {
      instance  = "m6i.large"
      min_nodes = 1
      max_nodes = 5
      disk_size = 100
      labels = {
        role = "general"
      }
    }
    worker = {
      instance  = "t3.medium"
      spot      = true
      min_nodes = 1
      max_nodes = 6
      taints = [{
        key    = "dedicated"
        value  = "batch-jobs"
        effect = "NO_SCHEDULE"
      }]
    }
  }

  # EFS configuration
  efs_enabled          = true
  efs_performance_mode = "generalPurpose"
  efs_throughput_mode  = "elastic"
  efs_encrypted        = true

  tags = {
    Example = "eks-cluster"
    Project = "terraform-aws-eks-cluster"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_efs"></a> [efs](#module\_efs) | terraform-aws-modules/efs/aws | 2.0.0 |
| <a name="module_eks"></a> [eks](#module\_eks) | terraform-aws-modules/eks/aws | 21.11.0 |
| <a name="module_iam"></a> [iam](#module\_iam) | ./modules/iam | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | 6.5.1 |
| <a name="module_vpc_endpoints"></a> [vpc\_endpoints](#module\_vpc\_endpoints) | ./modules/vpc-endpoints | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | List of availability zones to use. If not specified, automatically selects up to 3 available AZs in the region. | `list(string)` | `[]` | no |
| <a name="input_cluster_enabled_log_types"></a> [cluster\_enabled\_log\_types](#input\_cluster\_enabled\_log\_types) | List of control plane logging types to enable. Default: ['authenticator']. Valid values: api, audit, authenticator, controllerManager, scheduler | `list(string)` | <pre>[<br/>  "authenticator"<br/>]</pre> | no |
| <a name="input_create_iam_roles"></a> [create\_iam\_roles](#input\_create\_iam\_roles) | Whether to create new IAM roles for the EKS cluster and node groups. If false, existing\_cluster\_iam\_role\_arn and existing\_node\_iam\_role\_arn must be provided. | `bool` | `true` | no |
| <a name="input_create_security_group"></a> [create\_security\_group](#input\_create\_security\_group) | Whether to create a new security group for the EKS cluster. If false, existing\_security\_group\_id must be provided. | `bool` | `true` | no |
| <a name="input_create_vpc"></a> [create\_vpc](#input\_create\_vpc) | Whether to create a new VPC with subnets. If false, existing private subnet IDs and security group ID must be provided. | `bool` | `true` | no |
| <a name="input_efs_enabled"></a> [efs\_enabled](#input\_efs\_enabled) | Whether to create an EFS file system for the cluster. | `bool` | `false` | no |
| <a name="input_efs_encrypted"></a> [efs\_encrypted](#input\_efs\_encrypted) | Whether to enable encryption at rest for the EFS file system. | `bool` | `true` | no |
| <a name="input_efs_kms_key_arn"></a> [efs\_kms\_key\_arn](#input\_efs\_kms\_key\_arn) | The ARN of the KMS key to use for encryption at rest. | `string` | `null` | no |
| <a name="input_efs_performance_mode"></a> [efs\_performance\_mode](#input\_efs\_performance\_mode) | The performance mode of the EFS file system. Default is `generalPurpose`. | `string` | `"generalPurpose"` | no |
| <a name="input_efs_provisioned_throughput_in_mibps"></a> [efs\_provisioned\_throughput\_in\_mibps](#input\_efs\_provisioned\_throughput\_in\_mibps) | The provisioned throughput in MiB/s for the EFS file system. Required if throughput\_mode is set to provisioned. | `number` | `null` | no |
| <a name="input_efs_throughput_mode"></a> [efs\_throughput\_mode](#input\_efs\_throughput\_mode) | The throughput mode of the EFS file system. Default is `bursting`. | `string` | `"bursting"` | no |
| <a name="input_eks_kms_arn"></a> [eks\_kms\_arn](#input\_eks\_kms\_arn) | The ARN of the KMS key to use for encrypting EKS secrets. If not provided, EKS secrets will not be encrypted. | `string` | `null` | no |
| <a name="input_endpoint_private_access"></a> [endpoint\_private\_access](#input\_endpoint\_private\_access) | Indicates whether the Amazon EKS private API server endpoint is enabled. | `bool` | `true` | no |
| <a name="input_endpoint_public_access"></a> [endpoint\_public\_access](#input\_endpoint\_public\_access) | Indicates whether the Amazon EKS public API server endpoint is enabled. | `bool` | `false` | no |
| <a name="input_endpoint_public_access_cidrs"></a> [endpoint\_public\_access\_cidrs](#input\_endpoint\_public\_access\_cidrs) | List of CIDR blocks which can access the Amazon EKS public API server endpoint. | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_existing_cluster_iam_role_arn"></a> [existing\_cluster\_iam\_role\_arn](#input\_existing\_cluster\_iam\_role\_arn) | ARN of an existing IAM role to use for the EKS cluster. Required when create\_cluster\_iam\_role is false. | `string` | `null` | no |
| <a name="input_existing_node_iam_role_arn"></a> [existing\_node\_iam\_role\_arn](#input\_existing\_node\_iam\_role\_arn) | ARN of an existing IAM role to use for the EKS node groups. Required when create\_iam\_roles is false. | `string` | `null` | no |
| <a name="input_existing_private_subnet_ids"></a> [existing\_private\_subnet\_ids](#input\_existing\_private\_subnet\_ids) | List of existing private subnet IDs to use if not creating a new VPC. | `list(string)` | `[]` | no |
| <a name="input_existing_security_group_id"></a> [existing\_security\_group\_id](#input\_existing\_security\_group\_id) | ID of an existing security group to use. Required when create\_security\_group is false. | `string` | `null` | no |
| <a name="input_existing_vpc_id"></a> [existing\_vpc\_id](#input\_existing\_vpc\_id) | ID of an existing VPC to use. Required when create\_vpc is false. | `string` | `null` | no |
| <a name="input_iam_role_permissions_boundary"></a> [iam\_role\_permissions\_boundary](#input\_iam\_role\_permissions\_boundary) | The ARN of the policy that is used to set the permissions boundary for IAM roles created by this module. | `string` | `null` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes `<major>.<minor>` version to use for the EKS cluster (i.e.: `1.33`) | `string` | `null` | no |
| <a name="input_node_groups"></a> [node\_groups](#input\_node\_groups) | Map of node groups to create. Each node group supports the following attributes:<br/>- instance (required): EC2 instance type (e.g., "m5.xlarge")<br/>- min\_nodes: Minimum number of nodes (default: 0)<br/>- max\_nodes: Maximum number of nodes (default: 1)<br/>- gpu: Set to true for GPU instances (default: false, uses AL2023 NVIDIA AMI)<br/>- ami\_type: Override AMI type (AL2023\_x86\_64\_STANDARD, AL2023\_ARM\_64\_STANDARD, AL2023\_x86\_64\_NVIDIA, etc.)<br/>- spot: Use Spot instances for cost savings (default: false)<br/>- disk\_size: Root disk size in GB (default: 20)<br/>- labels: Map of Kubernetes labels to apply to nodes (default: {})<br/>- taints: List of Kubernetes taints with keys: key, value, effect | <pre>map(object({<br/>    instance  = string<br/>    min_nodes = optional(number, 0)<br/>    max_nodes = optional(number, 1)<br/>    gpu       = optional(bool, false)<br/>    ami_type  = optional(string, null)<br/>    spot      = optional(bool, false)<br/>    disk_size = optional(number, null)<br/>    labels    = optional(map(string), {})<br/>    taints = optional(list(object({<br/>      key    = string<br/>      value  = string<br/>      effect = string # NO_SCHEDULE, NO_EXECUTE, or PREFER_NO_SCHEDULE<br/>    })), [])<br/>  }))</pre> | n/a | yes |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | The name of the project. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |
| <a name="input_vpc_cidr_block"></a> [vpc\_cidr\_block](#input\_vpc\_cidr\_block) | The CIDR block for the VPC. | `string` | `"10.0.0.0/16"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | The Amazon Resource Name (ARN) of the cluster |
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | Base64 encoded certificate data required to communicate with the cluster |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | Endpoint for your Kubernetes API server |
| <a name="output_cluster_iam_role_arn"></a> [cluster\_iam\_role\_arn](#output\_cluster\_iam\_role\_arn) | IAM role ARN of the EKS cluster |
| <a name="output_cluster_id"></a> [cluster\_id](#output\_cluster\_id) | The ID of the EKS cluster |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | The name of the EKS cluster |
| <a name="output_cluster_oidc_issuer_url"></a> [cluster\_oidc\_issuer\_url](#output\_cluster\_oidc\_issuer\_url) | The URL on the EKS cluster for the OpenID Connect identity provider |
| <a name="output_cluster_security_group_id"></a> [cluster\_security\_group\_id](#output\_cluster\_security\_group\_id) | Security group ID attached to the EKS cluster |
| <a name="output_efs_arn"></a> [efs\_arn](#output\_efs\_arn) | The ARN of the EFS file system (null if EFS not enabled) |
| <a name="output_efs_dns_name"></a> [efs\_dns\_name](#output\_efs\_dns\_name) | The DNS name of the EFS file system (null if EFS not enabled) |
| <a name="output_efs_id"></a> [efs\_id](#output\_efs\_id) | The ID of the EFS file system (null if EFS not enabled) |
| <a name="output_kubeconfig_command"></a> [kubeconfig\_command](#output\_kubeconfig\_command) | Command to update kubeconfig |
| <a name="output_node_groups"></a> [node\_groups](#output\_node\_groups) | Outputs from EKS node groups |
| <a name="output_node_iam_role_arn"></a> [node\_iam\_role\_arn](#output\_node\_iam\_role\_arn) | IAM role ARN used by EKS node groups |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | ARN of the OIDC Provider for EKS (for IRSA) |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | List of IDs of private subnets used by the EKS cluster |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | List of IDs of created public subnets (null if using existing subnets) |
| <a name="output_vpc_endpoints_security_group_id"></a> [vpc\_endpoints\_security\_group\_id](#output\_vpc\_endpoints\_security\_group\_id) | Security group ID used by VPC endpoints (null if VPC endpoints not created) |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | The ID of the VPC used by the EKS cluster |
<!-- END_TF_DOCS -->
