data "aws_vpc_endpoint_service" "interface" {
  for_each = toset(var.interface_vpc_endpoint_services)

  service      = each.value
  service_type = "Interface"
}

resource "aws_vpc_endpoint" "interface" {
  for_each = data.aws_vpc_endpoint_service.interface

  vpc_id              = var.vpc_id
  service_name        = each.value.service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = var.security_group_ids
  private_dns_enabled = true

  tags = var.tags
}

data "aws_vpc_endpoint_service" "gateway" {
  for_each = toset(var.gateway_vpc_endpoint_services)

  service      = each.value
  service_type = "Gateway"
}

resource "aws_vpc_endpoint" "gateway" {
  for_each = data.aws_vpc_endpoint_service.gateway

  vpc_id            = var.vpc_id
  service_name      = each.value.service_name
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids

  tags = var.tags
}
