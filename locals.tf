data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_region" "current" {}

locals {

  # Determine availability zones to use. If not specified, select up to 3 available AZs in the region.
  availability_zones = length(var.availability_zones) > 0 ? var.availability_zones : slice(
    data.aws_availability_zones.available.names,
    0,
    min(3, length(data.aws_availability_zones.available.names))
  )

  # Calculate subnet CIDRs using cidrsubnet
  # For a /16 VPC, creates /20 subnets (16 + 4 = 20)
  # Public subnets:  indices 0-7  (10.10.0.0/20, 10.10.16.0/20, 10.10.32.0/20, ...)
  # Private subnets: indices 8-15 (10.10.128.0/20, 10.10.144.0/20, 10.10.160.0/20, ...)
  public_subnets  = [for i in range(length(local.availability_zones)) : cidrsubnet(var.vpc_cidr_block, 4, i)]
  private_subnets = [for i in range(length(local.availability_zones)) : cidrsubnet(var.vpc_cidr_block, 4, i + 8)]

  # Private subnet IDs to use for the EKS cluster and EFS mount targets are the ones created
  # with the VPC if existing ones are not provided.
  private_subnet_ids = var.create_vpc ? flatten(module.vpc[*].private_subnets) : var.existing_private_subnet_ids

  interface_vpc_endpoint_services = var.create_vpc && var.create_vpc_endpoints ? [
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
  gateway_vpc_endpoint_services = var.create_vpc && var.create_vpc_endpoints ? [
    "s3",
  ] : []

  # Cluster security group is the one automatically created by EKS unless an existing
  # one is provided.
  cluster_security_group_id = var.existing_security_group_id != null ? var.existing_security_group_id : module.eks.cluster_security_group_id

  node_iam_role_arn = var.existing_node_iam_role_arn != null ? var.existing_node_iam_role_arn : one(module.iam[*].node_iam_role_arn)

  # Map node groups to the format expected by the EKS module
  node_groups = {
    for name, config in var.node_groups : name => {
      name = name

      instance_types = [config.instance]
      capacity_type  = config.spot ? "SPOT" : "ON_DEMAND"
      disk_size      = config.disk_size

      min_size     = config.min_nodes
      max_size     = config.max_nodes
      desired_size = config.min_nodes

      ami_type = config.ami_type != null ? config.ami_type : (
        config.gpu ? "AL2023_x86_64_NVIDIA" : "AL2023_x86_64_STANDARD"
      )

      # Use a shared IAM role for all node groups instead of creating or specifying
      # individual ones
      create_iam_role = false
      iam_role_arn    = local.node_iam_role_arn

      labels = config.labels

      # The EKS module expects taints as a map
      taints = {
        for idx, taint in config.taints :
        idx => {
          key    = taint.key
          value  = taint.value
          effect = taint.effect
        }
      }
    }
  }

  # Map each private subnet ID to its EFS mount target configuration
  efs_mount_targets = var.efs_enabled ? {
    for idx, subnet_id in local.private_subnet_ids :
    idx => {
      subnet_id       = subnet_id
      security_groups = [local.cluster_security_group_id]
    }
  } : {}
}
