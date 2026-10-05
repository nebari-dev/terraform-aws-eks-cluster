output "single_az_id" {
  description = "Filesystem ID of the Single-AZ FSx for OpenZFS filesystem; empty when disabled"
  value       = try(aws_fsx_openzfs_file_system.single_az[0].id, "")
}

output "single_az_dns_name" {
  description = "DNS name of the Single-AZ FSx for OpenZFS filesystem; empty when disabled"
  value       = try(aws_fsx_openzfs_file_system.single_az[0].dns_name, "")
}

output "single_az_root_volume_id" {
  description = "Root volume ID of the Single-AZ filesystem, used as the CSI parent volume; empty when disabled"
  value       = try(aws_fsx_openzfs_file_system.single_az[0].root_volume_id, "")
}

output "multi_az_id" {
  description = "Filesystem ID of the Multi-AZ FSx for OpenZFS filesystem; empty when disabled"
  value       = try(aws_fsx_openzfs_file_system.multi_az[0].id, "")
}

output "multi_az_dns_name" {
  description = "DNS name of the Multi-AZ FSx for OpenZFS filesystem; empty when disabled"
  value       = try(aws_fsx_openzfs_file_system.multi_az[0].dns_name, "")
}

output "multi_az_root_volume_id" {
  description = "Root volume ID of the Multi-AZ filesystem, used as the CSI parent volume; empty when disabled"
  value       = try(aws_fsx_openzfs_file_system.multi_az[0].root_volume_id, "")
}
