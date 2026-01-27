data "aws_availability_zones" "available" {
  state = "available"
}


resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

# Create three (one per AZ) public subnets (for NAT Gateways)
resource "aws_subnet" "public" {
  count                   = 3
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = { "kubernetes.io/role/elb" = "1" }
}

# Create three private subnets (for EKS nodes)
resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = { "kubernetes.io/role/internal-elb" = "1" }
}

# Create Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  depends_on = [aws_internet_gateway.main]
}

# Create a single NAT Gateway (more can be created for high availability)
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  depends_on = [aws_internet_gateway.main]
}

# Create route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Create route table for private subnets (shared across all private subnets)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
}

# Associate private subnets with the route table
resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Create security group for the cluster with minimum requirements for EKS cluster communication:
resource "aws_security_group" "cluster" {
  name        = "eks-cluster-custom-sg"
  description = "Security group for the EKS cluster with minimum required rules"
  vpc_id      = aws_vpc.main.id
}

# Egress: Allow all outbound traffic (nodes need to pull images, reach AWS APIs, etc.)
resource "aws_vpc_security_group_egress_rule" "cluster_egress_all" {
  security_group_id = aws_security_group.cluster.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all outbound traffic"
}

# Ingress: Kubernetes API server (required for kubectl and node-to-control-plane communication)
resource "aws_vpc_security_group_ingress_rule" "cluster_ingress_https" {
  security_group_id            = aws_security_group.cluster.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.cluster.id
  description                  = "Allow HTTPS traffic for Kubernetes API server"
}

# Ingress: Kubelet API (required for control plane to communicate with worker nodes)
resource "aws_vpc_security_group_ingress_rule" "cluster_ingress_kubelet" {
  security_group_id            = aws_security_group.cluster.id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.cluster.id
  description                  = "Allow kubelet API communication"
}

# Ingress: CoreDNS TCP (required for DNS resolution within the cluster)
resource "aws_vpc_security_group_ingress_rule" "cluster_ingress_coredns_tcp" {
  security_group_id            = aws_security_group.cluster.id
  from_port                    = 53
  to_port                      = 53
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.cluster.id
  description                  = "Allow CoreDNS TCP traffic"
}

# Ingress: CoreDNS UDP (required for DNS resolution within the cluster)
resource "aws_vpc_security_group_ingress_rule" "cluster_ingress_coredns_udp" {
  security_group_id            = aws_security_group.cluster.id
  from_port                    = 53
  to_port                      = 53
  ip_protocol                  = "udp"
  referenced_security_group_id = aws_security_group.cluster.id
  description                  = "Allow CoreDNS UDP traffic"
}

# Ingress: NFS (required for EFS mount targets)
resource "aws_vpc_security_group_ingress_rule" "cluster_ingress_nfs" {
  security_group_id            = aws_security_group.cluster.id
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.cluster.id
  description                  = "Allow NFS traffic for EFS"
}
