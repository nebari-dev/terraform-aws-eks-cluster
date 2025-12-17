resource "aws_vpc" "main" {
  count = local.create_vpc ? 1 : 0

  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-vpc"
  })
}

resource "aws_internet_gateway" "main" {
  count = local.create_vpc ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  tags = merge(var.tags, {
    Name = "${var.project_name}-igw"
  })
}

resource "aws_subnet" "public" {
  count = local.create_vpc ? length(local.availability_zones) : 0

  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = local.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name                     = "${var.project_name}-public-${local.availability_zones[count.index]}"
    Type                     = "public"
    "kubernetes.io/role/elb" = "1" # For AWS Load Balancer Controller
  })
}

resource "aws_subnet" "private" {
  count = local.create_vpc ? length(local.availability_zones) : 0

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = local.availability_zones[count.index]

  tags = merge(var.tags, {
    Name                              = "${var.project_name}-private-${local.availability_zones[count.index]}"
    Type                              = "private"
    "kubernetes.io/role/internal-elb" = "1" # For internal load balancers
  })
}

resource "aws_eip" "nat" {
  count = local.create_vpc ? length(local.availability_zones) : 0

  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.project_name}-eip-nat-${local.availability_zones[count.index]}"
  })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count = local.create_vpc ? length(local.availability_zones) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = "${var.project_name}-nat-${local.availability_zones[count.index]}"
  })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  count = local.create_vpc ? 1 : 0

  vpc_id = aws_vpc.main[0].id

  tags = merge(var.tags, {
    Name = "${var.project_name}-rt-public"
  })
}

resource "aws_route" "public_internet" {
  count = local.create_vpc ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main[0].id
}

resource "aws_route_table_association" "public" {
  count = local.create_vpc ? length(local.availability_zones) : 0

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table" "private" {
  count = local.create_vpc ? length(local.availability_zones) : 0

  vpc_id = aws_vpc.main[0].id

  tags = merge(var.tags, {
    Name = "${var.project_name}-rt-private-${local.availability_zones[count.index]}"
  })
}

resource "aws_route" "private_nat" {
  count = local.create_vpc ? length(local.availability_zones) : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[count.index].id
}

resource "aws_route_table_association" "private" {
  count = local.create_vpc ? length(local.availability_zones) : 0

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_security_group" "cluster" {
  count = local.create_vpc && var.existing_security_group_id == null ? 1 : 0

  name        = "${local.cluster_name}-sg-cluster"
  description = "Security group for ${local.cluster_name} EKS cluster"
  vpc_id      = aws_vpc.main[0].id

  tags = merge(var.tags, {
    Name = "${var.project_name}-cluster-sg"
  })
}

# Allow HTTPS (443) from nodes to control plane
resource "aws_security_group_rule" "cluster_ingress_https" {
  count = local.create_vpc && var.existing_security_group_id == null ? 1 : 0

  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster[0].id
  source_security_group_id = aws_security_group.cluster[0].id
  description              = "Allow nodes to communicate with cluster API server"
}

# Allow kubelet API (10250) from control plane to nodes
resource "aws_security_group_rule" "cluster_ingress_kubelet" {
  count = local.create_vpc && var.existing_security_group_id == null ? 1 : 0

  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster[0].id
  source_security_group_id = aws_security_group.cluster[0].id
  description              = "Allow control plane to communicate with nodes kubelet"
}

# Allow DNS TCP (53) within cluster
resource "aws_security_group_rule" "cluster_ingress_dns_tcp" {
  count = local.create_vpc && var.existing_security_group_id == null ? 1 : 0

  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster[0].id
  source_security_group_id = aws_security_group.cluster[0].id
  description              = "Allow DNS TCP communication within cluster"
}

# Allow DNS UDP (53) within cluster
resource "aws_security_group_rule" "cluster_ingress_dns_udp" {
  count = local.create_vpc && var.existing_security_group_id == null ? 1 : 0

  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "udp"
  security_group_id        = aws_security_group.cluster[0].id
  source_security_group_id = aws_security_group.cluster[0].id
  description              = "Allow DNS UDP communication within cluster"
}

# Allow node-to-node communication on ephemeral ports (for CoreDNS, node port services, etc.)
resource "aws_security_group_rule" "cluster_ingress_ephemeral" {
  count = local.create_vpc && var.existing_security_group_id == null ? 1 : 0

  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster[0].id
  source_security_group_id = aws_security_group.cluster[0].id
  description              = "Allow node-to-node communication"
}

# Allow all outbound traffic (required for NAT gateway, pulling images, etc.)
resource "aws_security_group_rule" "cluster_egress_all" {
  count = local.create_vpc && var.existing_security_group_id == null ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1" # all protocols
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.cluster[0].id
  description       = "Allow all outbound traffic"
}

# Interface VPC Endpoints

data "aws_vpc_endpoint_service" "interface" {
  for_each = toset(local.interface_vpc_endpoint_services)

  service = each.value
}

resource "aws_vpc_endpoint" "interface" {
  for_each = data.aws_vpc_endpoint_service.interface

  vpc_id              = aws_vpc.main[0].id
  service_name        = each.value.service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = compact([local.custom_cluster_security_group_id, aws_eks_cluster.main.vpc_config[0].cluster_security_group_id])
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-vpce-${each.key}"
  })
}

# Gateway VPC Endpoint, required for S3 (pulling image layers)

data "aws_vpc_endpoint_service" "s3" {
  count = local.create_vpc ? 1 : 0

  service      = "s3"
  service_type = "Gateway"
}

resource "aws_vpc_endpoint" "s3" {
  count = local.create_vpc ? 1 : 0

  vpc_id            = aws_vpc.main[0].id
  service_name      = data.aws_vpc_endpoint_service.s3[0].service_name # From data source
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat([aws_route_table.public[0].id], aws_route_table.private[*].id)

  tags = merge(var.tags, {
    Name = "${var.project_name}-vpce-s3"
  })
}
