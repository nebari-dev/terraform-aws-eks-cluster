output "node_iam_role_arn" {
  description = "IAM role ARN for the EKS node group"
  value       = aws_iam_role.node.arn
}
