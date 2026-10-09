variable "project_name" {
  description = "The name of the project. Prefixes the security group, IAM policy and Pod Identity role names."
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster to associate the FSx for OpenZFS CSI controller pod identity with."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC the filesystem is placed in. Its CIDR is the NFS export client range."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs. SINGLE_AZ_2 uses the first; MULTI_AZ_1 uses the first two (the first is preferred), which must be in different AZs."
  type        = list(string)
}

variable "route_table_ids" {
  description = "Route tables of every subnet the cluster nodes run in. MULTI_AZ_1 adds routes to its floating endpoint to these; ignored for SINGLE_AZ_2."
  type        = list(string)
  default     = []
}

variable "node_security_group_id" {
  description = "Security group ID of the cluster nodes, allowed NFS ingress to the filesystem."
  type        = string
}

variable "deployment_type" {
  description = "FSx for OpenZFS deployment type: MULTI_AZ_1 or SINGLE_AZ_2."
  type        = string
  default     = "MULTI_AZ_1"

  validation {
    condition     = contains(["MULTI_AZ_1", "SINGLE_AZ_2"], var.deployment_type)
    error_message = "deployment_type must be MULTI_AZ_1 or SINGLE_AZ_2."
  }
}

variable "storage_capacity" {
  description = "Storage capacity of the filesystem in GiB, from 64 to 524288."
  type        = number
  default     = 64

  # https://docs.aws.amazon.com/fsx/latest/APIReference/API_CreateFileSystem.html#FSx-CreateFileSystem-request-StorageCapacity
  validation {
    condition     = var.storage_capacity >= 64 && var.storage_capacity <= 524288
    error_message = "storage_capacity must be between 64 and 524288 GiB."
  }
}

variable "throughput" {
  description = "Provisioned throughput of the filesystem in MBps: 160, 320, 640, 1280, 2560, 3840, 5120, 7680 or 10240."
  type        = number
  default     = 160

  # https://docs.aws.amazon.com/fsx/latest/APIReference/API_CreateFileSystemOpenZFSConfiguration.html#FSx-Type-CreateFileSystemOpenZFSConfiguration-ThroughputCapacity
  validation {
    condition     = contains([160, 320, 640, 1280, 2560, 3840, 5120, 7680, 10240], var.throughput)
    error_message = "throughput must be one of 160, 320, 640, 1280, 2560, 3840, 5120, 7680 or 10240."
  }
}

variable "automatic_backup_retention_days" {
  description = "Days to keep automatic daily backups of the filesystem, from 0 to 90. 0 disables automatic backups."
  type        = number
  default     = 7

  validation {
    condition     = var.automatic_backup_retention_days >= 0 && var.automatic_backup_retention_days <= 90
    error_message = "automatic_backup_retention_days must be between 0 and 90."
  }
}

variable "skip_final_backup" {
  description = "Skip the final backup when the filesystem is deleted."
  type        = bool
  default     = false
}

variable "delete_child_volumes_on_destroy" {
  description = "Delete the CSI-created child volumes and snapshots together with the filesystem. When false, destroy fails while any remain."
  type        = bool
  default     = false
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
