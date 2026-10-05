variable "project_name" {
  description = "The name of the project. Prefixes the security group, IAM policy and Pod Identity role names."
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster to associate the FSx for OpenZFS CSI controller pod identity with."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC the filesystems are placed in. Its CIDR is the NFS export client range."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs. Single-AZ uses the first; Multi-AZ uses the first two (the first is preferred)."
  type        = list(string)
}

variable "node_security_group_id" {
  description = "Security group ID of the cluster nodes, allowed NFS ingress to the filesystems."
  type        = string
}

variable "single_az_enabled" {
  description = "Create a SINGLE_AZ_2 FSx for OpenZFS filesystem."
  type        = bool
  default     = false
}

variable "multi_az_enabled" {
  description = "Create a MULTI_AZ_1 FSx for OpenZFS filesystem."
  type        = bool
  default     = false
}

variable "storage_capacity" {
  description = "Storage capacity of each filesystem in GiB. FSx for OpenZFS has a 64 GiB floor."
  type        = number
  default     = 64
}

variable "throughput" {
  description = "Provisioned throughput of each filesystem in MBps. 160 is the floor shared by SINGLE_AZ_2 and MULTI_AZ_1."
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
