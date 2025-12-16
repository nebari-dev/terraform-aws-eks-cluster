module "eks" {
  source = "../.."

  project_name = "eks-basic"

  node_groups = {
    general = {
      instance  = "m5.xlarge"
      min_nodes = 1
      max_nodes = 3
    }
  }
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}
