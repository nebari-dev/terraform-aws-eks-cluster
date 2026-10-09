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
