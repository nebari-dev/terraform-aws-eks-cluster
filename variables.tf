################################################################################
# Common
################################################################################
variable "project_name" {
  description = "The name of the project."
  type        = string
  default     = ""
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

################################################################################
# Networking
################################################################################
variable "availability_zones" {
  description = "List of availability zones to use. If not specified, automatically selects up to 3 available AZs in the region."
  type        = list(string)
  default     = []
}

variable "create_vpc" {
  description = "Whether to create a new VPC with subnets. If false, existing private subnet IDs and security group ID must be provided."
  type        = bool
  default     = true
}

variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "existing_vpc_id" {
  description = "ID of an existing VPC to use. Required when create_vpc is false."
  type        = string
  default     = null

  validation {
    condition     = var.create_vpc || var.existing_vpc_id != null
    error_message = "When 'create_vpc' is false, 'existing_vpc_id' must be provided."
  }
}

variable "existing_private_subnet_ids" {
  description = "List of existing private subnet IDs to use if not creating a new VPC."
  type        = list(string)
  default     = []

  validation {
    condition     = var.create_vpc || length(var.existing_private_subnet_ids) > 0
    error_message = "When 'create_vpc' is false, 'existing_private_subnet_ids' must be provided with at least one subnet ID."
  }
}

variable "create_security_group" {
  description = "Whether to create a new security group for the EKS cluster. If false, existing_security_group_id must be provided."
  type        = bool
  default     = true
}

variable "existing_security_group_id" {
  description = "ID of an existing security group to use. Required when create_security_group is false."
  type        = string
  default     = null

  validation {
    condition     = var.create_security_group || var.existing_security_group_id != null
    error_message = "When 'create_security_group' is false, 'existing_security_group_id' must be provided."
  }
}

################################################################################
# Cluster
################################################################################
variable "kubernetes_version" {
  description = "Kubernetes `<major>.<minor>` version to use for the EKS cluster (i.e.: `1.33`)"
  type        = string
  default     = null
}

variable "endpoint_private_access" {
  description = "Indicates whether the Amazon EKS private API server endpoint is enabled."
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Indicates whether the Amazon EKS public API server endpoint is enabled."
  type        = bool
  default     = false
}

variable "endpoint_public_access_cidrs" {
  description = "List of CIDR blocks which can access the Amazon EKS public API server endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "eks_kms_arn" {
  description = "The ARN of the KMS key to use for encrypting EKS secrets. If not provided, EKS secrets will not be encrypted."
  type        = string
  default     = null
}

variable "cluster_enabled_log_types" {
  description = "List of control plane logging types to enable. Default: ['authenticator']. Valid values: api, audit, authenticator, controllerManager, scheduler"
  type        = list(string)
  default     = ["authenticator"]

  validation {
    condition = alltrue([
      for log_type in var.cluster_enabled_log_types :
      contains(["api", "audit", "authenticator", "controllerManager", "scheduler"], log_type)
    ])
    error_message = "cluster_enabled_log_types must only contain: api, audit, authenticator, controllerManager, scheduler."
  }
}

variable "create_iam_roles" {
  description = "Whether to create new IAM roles for the EKS cluster and node groups. If false, existing_cluster_iam_role_arn and existing_node_iam_role_arn must be provided."
  type        = bool
  default     = true
}

variable "existing_cluster_iam_role_arn" {
  description = "ARN of an existing IAM role to use for the EKS cluster. Required when create_cluster_iam_role is false."
  type        = string
  default     = null
  validation {
    condition     = var.create_iam_roles || var.existing_cluster_iam_role_arn != null
    error_message = "When 'create_iam_roles' is false, 'existing_cluster_iam_role_arn' must be provided."
  }
}

variable "existing_node_iam_role_arn" {
  description = "ARN of an existing IAM role to use for the EKS node groups. Required when create_iam_roles is false."
  type        = string
  default     = null
  validation {
    condition     = var.create_iam_roles || var.existing_node_iam_role_arn != null
    error_message = "When 'create_iam_roles' is false, 'existing_node_iam_role_arn' must be provided."
  }
}

variable "iam_role_permissions_boundary" {
  description = "The ARN of the policy that is used to set the permissions boundary for IAM roles created by this module."
  type        = string
  default     = null
}

variable "node_groups" {
  description = <<-EOT
    Map of node groups to create. Each node group supports the following attributes:
    - instance (required): EC2 instance type (e.g., "m5.xlarge")
    - min_nodes: Minimum number of nodes (default: 0)
    - max_nodes: Maximum number of nodes (default: 1)
    - gpu: Set to true for GPU instances (default: false, uses AL2023 NVIDIA AMI)
    - ami_type: Override AMI type (AL2023_x86_64_STANDARD, AL2023_ARM_64_STANDARD, AL2023_x86_64_NVIDIA, etc.)
    - spot: Use Spot instances for cost savings (default: false)
    - disk_size: Root disk size in GB (default: 20)
    - labels: Map of Kubernetes labels to apply to nodes (default: {})
    - taints: List of Kubernetes taints with keys: key, value, effect
  EOT
  type = map(object({
    instance  = string
    min_nodes = optional(number, 0)
    max_nodes = optional(number, 1)
    gpu       = optional(bool, false)
    ami_type  = optional(string, null)
    spot      = optional(bool, false)
    disk_size = optional(number, null)
    labels    = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string # NO_SCHEDULE, NO_EXECUTE, or PREFER_NO_SCHEDULE
    })), [])
  }))

  validation {
    condition     = length(var.node_groups) > 0
    error_message = "At least one node group must be defined."
  }

  validation {
    condition = alltrue([
      for ng_name, ng in var.node_groups :
      ng.min_nodes >= 0 && ng.max_nodes >= ng.min_nodes
    ])
    error_message = "For each node group, min_nodes must be >= 0 and max_nodes must be >= min_nodes."
  }

  validation {
    condition = alltrue(flatten([
      for ng_name, ng in var.node_groups : [
        for taint in ng.taints :
        contains(["NO_SCHEDULE", "NO_EXECUTE", "PREFER_NO_SCHEDULE"], taint.effect)
      ]
    ]))
    error_message = "Taint effect must be one of: NO_SCHEDULE, NO_EXECUTE, or PREFER_NO_SCHEDULE."
  }
}

################################################################################
# EFS
################################################################################
variable "efs_enabled" {
  description = "Whether to create an EFS file system for the cluster."
  type        = bool
  default     = false
}

variable "efs_performance_mode" {
  description = "The performance mode of the EFS file system. Default is `generalPurpose`."
  type        = string
  default     = "generalPurpose"
}

variable "efs_throughput_mode" {
  description = "The throughput mode of the EFS file system. Default is `bursting`."
  type        = string
  default     = "bursting"
}

variable "efs_provisioned_throughput_in_mibps" {
  description = "The provisioned throughput in MiB/s for the EFS file system. Required if throughput_mode is set to provisioned."
  type        = number
  default     = null
}

variable "efs_encrypted" {
  description = "Whether to enable encryption at rest for the EFS file system."
  type        = bool
  default     = true
}

variable "efs_kms_key_arn" {
  description = "The ARN of the KMS key to use for encryption at rest."
  type        = string
  default     = null
}
