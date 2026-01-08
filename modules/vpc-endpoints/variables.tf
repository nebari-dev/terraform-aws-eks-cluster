variable "vpc_id" {
  description = "The ID of the VPC where to create the endpoints."
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for interface VPC endpoints."
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for interface VPC endpoints."
  type        = list(string)
}

variable "route_table_ids" {
  description = "List of route table IDs for gateway VPC endpoints."
  type        = list(string)
}

variable "interface_vpc_endpoint_services" {
  description = "List of interface VPC endpoint services to create."
  type        = list(string)
}

variable "gateway_vpc_endpoint_services" {
  description = "List of gateway VPC endpoint services to create."
  type        = list(string)
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
