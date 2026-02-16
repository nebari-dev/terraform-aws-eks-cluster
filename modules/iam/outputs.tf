output "node_iam_role_arn" {
  description = "IAM role ARN for the EKS node group. Returns null if create is false."
  value       = var.create ? aws_iam_role.node[0].arn : null
}
