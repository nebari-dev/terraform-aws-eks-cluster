output "security_group_id" {
  description = "The ID of the VPC endpoints security group"
  value       = aws_security_group.vpc_endpoints.id
}
