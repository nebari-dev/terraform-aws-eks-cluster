variable "cluster_name" {
  description = "The name of the EKS cluster."
  type        = string
}

variable "permissions_boundary" {
  description = "The ARN of the IAM permissions boundary to attach to the IAM roles."
  type        = string
  default     = null
}

variable "tags" {
  description = "A map of tags to assign to resources."
  type        = map(string)
  default     = {}
}
