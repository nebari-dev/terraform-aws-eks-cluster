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
  description = "Private subnet IDs. SINGLE_AZ_2 uses the first; MULTI_AZ_1 uses the first two (the first is preferred)."
  type        = list(string)
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
  description = "Storage capacity of the filesystem in GiB. FSx for OpenZFS has a 64 GiB floor."
  type        = number
  default     = 64
}

variable "throughput" {
  description = "Provisioned throughput of the filesystem in MBps. 160 is the floor shared by SINGLE_AZ_2 and MULTI_AZ_1."
  type        = number
  default     = 160
}

variable "compression" {
  description = "ZFS compression on the root volume: LZ4, ZSTD or NONE."
  type        = string
  default     = "LZ4"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
