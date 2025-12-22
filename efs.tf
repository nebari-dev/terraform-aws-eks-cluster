resource "aws_efs_file_system" "main" {
  count = var.efs_enabled ? 1 : 0

  creation_token = "${local.cluster_name}-efs"

  performance_mode = var.efs_performance_mode
  throughput_mode  = var.efs_throughput_mode

  # Only applicable when throughput_mode is 'provisioned'
  provisioned_throughput_in_mibps = var.efs_throughput_mode == "provisioned" ? var.efs_provisioned_throughput_in_mibps : null

  encrypted  = var.efs_encrypted
  kms_key_id = var.efs_encrypted && var.efs_kms_key_id != null ? var.efs_kms_key_id : null

  tags = var.tags
}


# Create one mount target per private subnet (one per AZ)
resource "aws_efs_mount_target" "main" {
  count = var.efs_enabled && local.create_vpc ? length(local.availability_zones) : 0

  file_system_id = aws_efs_file_system.main[0].id
  subnet_id      = aws_subnet.private[count.index].id
  security_groups = [local.custom_cluster_security_group_id]
}
