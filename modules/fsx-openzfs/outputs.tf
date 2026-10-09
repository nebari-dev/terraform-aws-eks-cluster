output "id" {
  description = "Filesystem ID of the FSx for OpenZFS filesystem"
  value       = aws_fsx_openzfs_file_system.this.id
}

output "dns_name" {
  description = "DNS name of the FSx for OpenZFS filesystem"
  value       = aws_fsx_openzfs_file_system.this.dns_name
}

output "root_volume_id" {
  description = "Root volume ID of the FSx for OpenZFS filesystem, used as the CSI parent volume"
  value       = aws_fsx_openzfs_file_system.this.root_volume_id
}

output "security_group_id" {
  description = "ID of the security group that allows NFS from the cluster nodes to the filesystem"
  value       = aws_security_group.this.id
}

output "csi_role_arn" {
  description = "IAM role ARN for the FSx for OpenZFS CSI controller pod identity association"
  value       = module.csi_pod_identity.iam_role_arn
}
