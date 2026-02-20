module "cluster" {
  source = "../.."

  project_name = "ex-existing-resources"

  # Use existing VPC and subnets
  create_vpc                  = false
  existing_vpc_id             = aws_vpc.main.id
  existing_private_subnet_ids = aws_subnet.private[*].id

  # Use existing security group
  create_security_group      = false
  existing_security_group_id = aws_security_group.cluster.id

  # Use existing IAM roles
  create_iam_roles              = false
  existing_cluster_iam_role_arn = aws_iam_role.cluster.arn
  existing_node_iam_role_arn    = aws_iam_role.node.arn

  # Cluster configuration
  kubernetes_version      = "1.34"
  endpoint_private_access = true
  endpoint_public_access  = false
  node_groups = {
    general = {
      instance  = "m6i.large"
      min_nodes = 1
      max_nodes = 5
      disk_size = 100
      labels = {
        role = "general"
      }
    }
    worker = {
      instance  = "t3.medium"
      spot      = true
      min_nodes = 1
      max_nodes = 6
      taints = [{
        key    = "dedicated"
        value  = "batch-jobs"
        effect = "NO_SCHEDULE"
      }]
    }
  }

  # Enable EFS
  efs_enabled = true

  tags = {
    Example = "existing-resources"
    Project = "terraform-aws-eks-cluster"
  }
}
