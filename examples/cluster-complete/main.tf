module "cluster" {
  source = "../.."

  project_name = "cluster-complete"

  # VPC configuration
  create_vpc           = true
  availability_zones   = ["us-west-2a", "us-west-2b", "us-west-2c"]
  vpc_cidr_block       = "10.10.0.0/16"

  # Cluster configuration
  kubernetes_version        = "1.34"
  endpoint_private_access   = true
  endpoint_public_access    = true
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  node_groups = {
    general = {
      instance  = "m6i.large"
      min_nodes = 1
      max_nodes = 5
      disk_size = 100
    }
    worker = {
      instance  = "t3.medium"
      spot      = true
      min_nodes = 1
      max_nodes = 6
    }
  }

  # EFS configuration
  efs_enabled          = true
  efs_performance_mode = "generalPurpose"
  efs_throughput_mode  = "elastic"
  efs_encrypted        = true

  tags = {
    Example = "cluster-complete"
    Project = "terraform-aws-eks-cluster"
  }
}
