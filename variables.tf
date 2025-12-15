# =========================================
# General Configuration
# =========================================

variable "project_name" {
  description = "Name of the project/cluster. Used as the cluster name and for resource naming."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

# =========================================
# Networking Configuration
# =========================================

variable "availability_zones" {
  description = "List of availability zones to use. If not specified, automatically selects up to 3 available AZs in the region."
  type        = list(string)
  default     = []
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC. Must be in CIDR format with prefix."
  type        = string
  default     = "10.10.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr_block, 0))
    error_message = "VPC CIDR block must be a valid CIDR notation."
  }
}

variable "existing_subnet_ids" {
  description = "List of existing subnet IDs to use instead of creating new ones. If provided, skips VPC creation."
  type        = list(string)
  default     = []
}

variable "existing_security_group_id" {
  description = "Existing security group ID to use instead of creating a new one"
  type        = string
  default     = null
}

# =========================================
# Kubernetes Configuration
# =========================================

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = null
}

variable "eks_kms_arn" {
  description = "ARN of KMS key for envelope encryption of Kubernetes secrets at rest"
  type        = string
  default     = null
}

variable "eks_endpoint_access" {
  description = "Controls EKS API endpoint access: 'public', 'private', or 'public-and-private'"
  type        = string
  default     = "public-and-private"

  validation {
    condition     = contains(["public", "private", "public-and-private"], var.eks_endpoint_access)
    error_message = "eks_endpoint_access must be one of: 'public', 'private', or 'public-and-private'."
  }
}

variable "eks_public_access_cidrs" {
  description = "List of CIDR blocks allowed to access the EKS public endpoint. Only used if eks_endpoint_access includes 'public'."
  type        = list(string)
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
    - single_subnet: Place all nodes in single subnet (default: false, not recommended)
    - taints: List of Kubernetes taints with keys: key, value, effect
  EOT
  type = map(object({
    instance      = string
    min_nodes     = optional(number, 0)
    max_nodes     = optional(number, 1)
    gpu           = optional(bool, false)
    ami_type      = optional(string, null)
    spot          = optional(bool, false)
    disk_size     = optional(number, null)
    single_subnet = optional(bool, false)
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

# =========================================
# IAM Configuration
# =========================================

variable "permissions_boundary" {
  description = "IAM permissions boundary ARN to apply to all IAM roles"
  type        = string
  default     = null
}

# =========================================
# Resource Tagging
# =========================================

variable "tags" {
  description = "Custom tags to apply to all AWS resources"
  type        = map(string)
  default     = {}
}

# =========================================
# EFS Storage
# =========================================

variable "efs_enabled" {
  description = "Whether to create an EFS file system for shared storage"
  type        = bool
  default     = false
}

variable "efs_performance_mode" {
  description = "EFS performance mode: 'generalPurpose' or 'maxIO'."
  type        = string
  default     = "generalPurpose"

  validation {
    condition     = contains(["generalPurpose", "maxIO"], var.efs_performance_mode)
    error_message = "efs_performance_mode must be either 'generalPurpose' or 'maxIO'."
  }
}

variable "efs_throughput_mode" {
  description = "EFS throughput mode: 'bursting', 'provisioned', or 'elastic'."
  type        = string
  default     = "bursting"

  validation {
    condition     = contains(["bursting", "provisioned", "elastic"], var.efs_throughput_mode)
    error_message = "efs_throughput_mode must be one of: 'bursting', 'provisioned', or 'elastic'."
  }
}

variable "efs_provisioned_throughput_in_mibps" {
  description = "Provisioned throughput in MiB/s. Required when throughput_mode is 'provisioned'."
  type        = number
  default     = null
}

variable "efs_encrypted" {
  description = "Whether to enable encryption at rest for EFS. IMMUTABLE after creation."
  type        = bool
  default     = true
}

variable "efs_kms_key_id" {
  description = "ARN of KMS key for EFS encryption. IMMUTABLE after creation. Optional if encrypted=true."
  type        = string
  default     = null
}
