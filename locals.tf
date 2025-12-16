data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  cluster_name = var.project_name

  # VPC and networking resources won't be created if existing subnet IDs are provided
  create_vpc = length(var.existing_subnet_ids) == 0
  vpc_cidr   = var.vpc_cidr_block

  # Use existing subnets if provided, otherwise use created subnets
  subnet_ids = length(var.existing_subnet_ids) > 0 ? var.existing_subnet_ids : aws_subnet.private[*].id

  # Read availability zones from config or automatically discover up to 3 AZs in the region
  availability_zones = length(var.availability_zones) > 0 ? var.availability_zones : slice(
    data.aws_availability_zones.available.names,
    0,
    min(3, length(data.aws_availability_zones.available.names))
  )

  # Calculate subnet CIDRs using cidrsubnet
  # For a /16 VPC, creates /20 subnets (16 + 4 = 20)
  # Public subnets:  indices 0-7  (10.10.0.0/20, 10.10.16.0/20, 10.10.32.0/20, ...)
  # Private subnets: indices 8-15 (10.10.128.0/20, 10.10.144.0/20, 10.10.160.0/20, ...)
  public_subnet_cidrs = [
    for i in range(length(local.availability_zones)) :
    cidrsubnet(local.vpc_cidr, 4, i)
  ]
  private_subnet_cidrs = [
    for i in range(length(local.availability_zones)) :
    cidrsubnet(local.vpc_cidr, 4, i + 8)
  ]

  # Use passed existing security group ID or created one if none is passed. If no security
  # group was created because existing subnets IDs were provided, this will be null.
  custom_cluster_security_group_id = (
    var.existing_security_group_id != null
    ? var.existing_security_group_id
    : try(aws_security_group.cluster[0].id, null)
  )

  # EKS endpoint access configuration
  endpoint_config = {
    public_access  = contains(["public", "public-and-private"], var.eks_endpoint_access)
    private_access = contains(["private", "public-and-private"], var.eks_endpoint_access)
  }

  interface_vpc_endpoint_services = local.create_vpc ? [
    "ec2",
    "ecr.api",
    "ecr.dkr",
    "sts",
    "eks",
    "eks-auth",
    "logs",
    "elasticloadbalancing",
    "autoscaling",
  ] : []

}
