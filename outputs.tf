################################################################################
# Cluster
################################################################################
output "cluster_id" {
  description = "The ID of the EKS cluster"
  value       = module.eks.cluster_id
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS (for IRSA)"
  value       = module.eks.oidc_provider_arn
}

################################################################################
# Networking
################################################################################
output "vpc_id" {
  description = "The ID of the created VPC (null if using existing VPC)"
  value       = one(module.vpc[*].vpc_id)
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets used by the EKS cluster"
  value       = local.private_subnet_ids
}

output "public_subnet_ids" {
  description = "List of IDs of created public subnets (null if using existing subnets)"
  value       = flatten(module.vpc[*].public_subnets)
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = module.eks.cluster_iam_role_arn
}

output "node_iam_role_arn" {
  description = "IAM role ARN used by EKS node groups"
  value       = var.existing_node_iam_role_arn != null ? var.existing_node_iam_role_arn : one(module.iam[*].node_iam_role_arn)
}

output "node_groups" {
  description = "Outputs from EKS node groups"
  value       = module.eks.eks_managed_node_groups
}

################################################################################
# EFS
################################################################################
output "efs_id" {
  description = "The ID of the EFS file system (null if EFS not enabled)"
  value       = one(module.efs[*].id)
}

output "efs_arn" {
  description = "The ARN of the EFS file system (null if EFS not enabled)"
  value       = one(module.efs[*].arn)
}

output "efs_dns_name" {
  description = "The DNS name of the EFS file system (null if EFS not enabled)"
  value       = one(module.efs[*].dns_name)
}

################################################################################
# Misc
################################################################################
output "kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = "aws eks update-kubeconfig --region ${data.aws_region.current.region} --name ${module.eks.cluster_name}"
}
