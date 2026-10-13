output "cluster_id" {
  description = "The ID of the EKS cluster"
  value       = module.cluster.cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = module.cluster.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.cluster.cluster_certificate_authority_data
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS (for IRSA)"
  value       = module.cluster.oidc_provider_arn
}

output "kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = module.cluster.kubeconfig_command
}

output "fsx_openzfs_id" {
  description = "Filesystem ID of the FSx for OpenZFS filesystem (null if fsx_openzfs_enabled is false)"
  value       = module.cluster.fsx_openzfs_id
}

output "fsx_openzfs_dns_name" {
  description = "DNS name of the FSx for OpenZFS filesystem (null if fsx_openzfs_enabled is false)"
  value       = module.cluster.fsx_openzfs_dns_name
}

output "fsx_openzfs_root_volume_id" {
  description = "Root volume ID of the FSx for OpenZFS filesystem, used as the CSI parent volume (null if fsx_openzfs_enabled is false)"
  value       = module.cluster.fsx_openzfs_root_volume_id
}

output "fsx_openzfs_csi_driver_role_arn" {
  description = "IAM role ARN for the FSx for OpenZFS CSI controller pod identity association (null if fsx_openzfs_enabled is false)"
  value       = module.cluster.fsx_openzfs_csi_driver_role_arn
}
