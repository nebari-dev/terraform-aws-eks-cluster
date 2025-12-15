# This example creates a simple EKS cluster with minimal configuration

module "eks" {
  source = "../.."

  project_name = "nebari-aws-basic"

  # Basic node group configuration
  node_groups = {
    general = {
      instance  = "m5.xlarge"
      min_nodes = 1
      max_nodes = 3
    }
  }

  tags = {
    Environment = "development"
    Project     = "nebari"
  }
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}
