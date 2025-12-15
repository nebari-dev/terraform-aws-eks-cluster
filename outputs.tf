output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "Endpoint for the Kubernetes API server"
  value       = aws_eks_cluster.main.endpoint
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = try(aws_vpc.main[0].id, null)
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = try(aws_subnet.public[*].id, [])
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = local.subnet_ids
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = aws_iam_role.cluster.arn
}

output "node_iam_role_arn" {
  description = "IAM role ARN of the EKS node groups"
  value       = aws_iam_role.node.arn
}

output "efs_id" {
  description = "The ID of the EFS file system"
  value       = try(aws_efs_file_system.main[0].id, null)
}

output "efs_arn" {
  description = "ARN of the EFS file system"
  value       = try(aws_efs_file_system.main[0].arn, null)
}
