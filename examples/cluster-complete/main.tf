module "eks" {
  source = "../.."

  project_name = "cluster-complete"

  create_vpc         = true
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
  vpc_cidr_block     = "10.10.0.0/16"

  kubernetes_version        = "1.34"
  endpoint_private_access   = true
  endpoint_public_access    = false
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  node_groups = {
    general = {
      instance  = "m5.xlarge"
      min_nodes = 1
      max_nodes = 5
      disk_size = 100
    }
    gpu = {
      instance  = "g4dn.xlarge"
      min_nodes = 0
      max_nodes = 3
      gpu       = true
      taints = [{
        key    = "nvidia.com/gpu"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
    }
  }

  efs_enabled          = true
  efs_performance_mode = "generalPurpose"
  efs_throughput_mode  = "elastic"
  efs_encrypted        = true

  tags = {
    Environment = "production"
    Project     = "terraform-aws-eks-cluster"
  }
}
