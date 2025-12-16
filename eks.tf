resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = local.subnet_ids
    endpoint_public_access  = local.endpoint_config.public_access
    endpoint_private_access = local.endpoint_config.private_access
    public_access_cidrs     = local.endpoint_config.public_access ? var.eks_public_access_cidrs : null
    security_group_ids      = compact([local.cluster_security_group_id]) # compact will remove nulls
  }

  enabled_cluster_log_types = var.cluster_enabled_log_types

  # Because there is no way to conditionally set the encryption_config block, a dynamic 
  # block is used to only include it if a KMS ARN is provided.
  dynamic "encryption_config" {
    for_each = var.eks_kms_arn != null ? [1] : []
    content {
      provider {
        key_arn = var.eks_kms_arn
      }
      resources = ["secrets"]
    }
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.cluster_amazon_eks_cluster_policy,
    aws_iam_role_policy_attachment.cluster_amazon_eks_vpc_resource_controller,
    aws_vpc_endpoint.interface
  ]
}

resource "aws_eks_node_group" "main" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.main.name
  node_role_arn   = aws_iam_role.node.arn
  node_group_name = each.key

  # Use all private subnets by default, or single subnet if configured
  subnet_ids = each.value.single_subnet ? [local.subnet_ids[0]] : local.subnet_ids

  scaling_config {
    desired_size = each.value.min_nodes
    max_size     = each.value.max_nodes
    min_size     = each.value.min_nodes
  }

  instance_types = [each.value.instance]
  capacity_type  = each.value.spot ? "SPOT" : "ON_DEMAND"
  disk_size      = each.value.disk_size

  // AMI provided by user takes precedence, else it is determined based on GPU flag
  ami_type = (
    each.value.ami_type != null ? each.value.ami_type :
    each.value.gpu ? "AL2023_x86_64_NVIDIA" :
    "AL2023_x86_64_STANDARD"
  )

  labels = {
    "node-group" = each.key
  }

  # Apply taints if specified
  dynamic "taint" {
    for_each = each.value.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  tags = var.tags

  # Ensure IAM policies are attached before creating node groups
  depends_on = [
    aws_iam_role_policy_attachment.node_amazon_eks_worker_node_policy,
    aws_iam_role_policy_attachment.node_amazon_eks_cni_policy,
    aws_iam_role_policy_attachment.node_amazon_ec2_container_registry_read_only,
  ]

  # Allow external changes without Terraform plan difference
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group#ignoring-changes-to-desired-size
  # https://search.opentofu.org/provider/hashicorp/aws/latest/docs/resources/eks_node_group#ignoring-changes-to-desired-size
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}
