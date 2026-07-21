variable "project_name" {
  description = "The name of the project."
  type        = string
}

variable "create_bucket" {
  description = "Create an S3 bucket for Longhorn off-cluster backups."
  type        = bool
  default     = false
}

variable "bucket_name" {
  description = "Name of the Longhorn backup S3 bucket. Required when create_bucket or enable_pod_identity is true."
  type        = string
  default     = ""
}

variable "force_destroy" {
  description = "Allow `terraform destroy` to delete a non-empty Longhorn backup bucket. When false, a non-empty bucket blocks deletion, protecting existing backups."
  type        = bool
  default     = false
}

variable "noncurrent_version_expiration_days" {
  description = "Days after which noncurrent (deleted or overwritten) backup object versions are permanently removed. Acts as the recovery window for accidentally deleted backups."
  type        = number
  default     = 30
}

variable "enable_pod_identity" {
  description = "Provision an EKS Pod Identity association granting Longhorn's service account (longhorn-service-account in longhorn-system) scoped S3 access to the backup bucket."
  type        = bool
  default     = false
}

variable "cluster_name" {
  description = "Name of the EKS cluster to associate the Longhorn pod identity with. Required when enable_pod_identity is true."
  type        = string
  default     = ""
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
