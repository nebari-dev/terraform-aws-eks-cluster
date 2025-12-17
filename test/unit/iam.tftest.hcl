variables {
  project_name = "test-eks-cluster"
  node_groups = {
    test = {
      instance = "m5.large"
    }
  }
}

run "test_cluster_iam_role_created" {
  command = plan

  assert {
    condition     = aws_iam_role.cluster.name == "test-eks-cluster-cluster-role"
    error_message = "Cluster IAM role should be named after the cluster"
  }

  assert {
    condition     = length(aws_iam_role.cluster.assume_role_policy) > 0
    error_message = "Cluster role should have an assume role policy"
  }
}

run "test_cluster_role_trust_policy" {
  command = plan

  assert {
    condition     = jsondecode(aws_iam_role.cluster.assume_role_policy).Statement[0].Principal.Service == "eks.amazonaws.com"
    error_message = "Cluster role should trust EKS service"
  }

  assert {
    condition     = jsondecode(aws_iam_role.cluster.assume_role_policy).Statement[0].Action == "sts:AssumeRole"
    error_message = "Cluster role should allow AssumeRole action"
  }

  assert {
    condition     = jsondecode(aws_iam_role.cluster.assume_role_policy).Statement[0].Effect == "Allow"
    error_message = "Cluster role trust policy should have Allow effect"
  }
}

run "test_cluster_role_permissions_boundary" {
  command = plan

  variables {
    permissions_boundary = "arn:aws:iam::123456789012:policy/MyPermissionsBoundary"
  }

  assert {
    condition     = aws_iam_role.cluster.permissions_boundary == "arn:aws:iam::123456789012:policy/MyPermissionsBoundary"
    error_message = "Cluster role should have the specified permissions boundary"
  }
}

run "test_cluster_role_no_permissions_boundary" {
  command = plan

  assert {
    condition     = aws_iam_role.cluster.permissions_boundary == null
    error_message = "Cluster role should not have permissions boundary by default"
  }
}

run "test_cluster_role_policy_attachments" {
  command = plan

  assert {
    condition     = aws_iam_role_policy_attachment.cluster_amazon_eks_cluster_policy.role == "test-eks-cluster-cluster-role"
    error_message = "AmazonEKSClusterPolicy should be attached to cluster role"
  }

  assert {
    condition     = aws_iam_role_policy_attachment.cluster_amazon_eks_cluster_policy.policy_arn == "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    error_message = "Should attach AmazonEKSClusterPolicy"
  }

  assert {
    condition     = aws_iam_role_policy_attachment.cluster_amazon_eks_vpc_resource_controller.role == "test-eks-cluster-cluster-role"
    error_message = "AmazonEKSVPCResourceController should be attached to cluster role"
  }

  assert {
    condition     = aws_iam_role_policy_attachment.cluster_amazon_eks_vpc_resource_controller.policy_arn == "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
    error_message = "Should attach AmazonEKSVPCResourceController"
  }
}

run "test_node_iam_role_created" {
  command = plan

  assert {
    condition     = aws_iam_role.node.name == "test-eks-cluster-node-role"
    error_message = "Node IAM role should be named after the cluster"
  }

  assert {
    condition     = length(aws_iam_role.node.assume_role_policy) > 0
    error_message = "Node role should have an assume role policy"
  }
}

run "test_node_role_trust_policy" {
  command = plan

  assert {
    condition     = jsondecode(aws_iam_role.node.assume_role_policy).Statement[0].Principal.Service == "ec2.amazonaws.com"
    error_message = "Node role should trust EC2 service"
  }

  assert {
    condition     = jsondecode(aws_iam_role.node.assume_role_policy).Statement[0].Action == "sts:AssumeRole"
    error_message = "Node role should allow AssumeRole action"
  }

  assert {
    condition     = jsondecode(aws_iam_role.node.assume_role_policy).Statement[0].Effect == "Allow"
    error_message = "Node role trust policy should have Allow effect"
  }
}

run "test_node_role_permissions_boundary" {
  command = plan

  variables {
    permissions_boundary = "arn:aws:iam::123456789012:policy/MyPermissionsBoundary"
  }

  assert {
    condition     = aws_iam_role.node.permissions_boundary == "arn:aws:iam::123456789012:policy/MyPermissionsBoundary"
    error_message = "Node role should have the specified permissions boundary"
  }
}

run "test_node_role_policy_attachments" {
  command = plan

  assert {
    condition     = aws_iam_role_policy_attachment.node_amazon_eks_worker_node_policy.role == "test-eks-cluster-node-role"
    error_message = "AmazonEKSWorkerNodePolicy should be attached to node role"
  }

  assert {
    condition     = aws_iam_role_policy_attachment.node_amazon_eks_worker_node_policy.policy_arn == "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    error_message = "Should attach AmazonEKSWorkerNodePolicy"
  }

  assert {
    condition     = aws_iam_role_policy_attachment.node_amazon_eks_cni_policy.role == "test-eks-cluster-node-role"
    error_message = "AmazonEKS_CNI_Policy should be attached to node role"
  }

  assert {
    condition     = aws_iam_role_policy_attachment.node_amazon_eks_cni_policy.policy_arn == "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    error_message = "Should attach AmazonEKS_CNI_Policy"
  }

  assert {
    condition     = aws_iam_role_policy_attachment.node_amazon_ec2_container_registry_read_only.role == "test-eks-cluster-node-role"
    error_message = "AmazonEC2ContainerRegistryReadOnly should be attached to node role"
  }

  assert {
    condition     = aws_iam_role_policy_attachment.node_amazon_ec2_container_registry_read_only.policy_arn == "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    error_message = "Should attach AmazonEC2ContainerRegistryReadOnly"
  }
}

run "test_iam_roles_custom_tags" {
  command = plan

  variables {
    tags = {
      Project     = "foobar"
      Environment = "dev"
    }
  }

  assert {
    condition     = aws_iam_role.cluster.tags["Project"] == "foobar"
    error_message = "Cluster role should have Project tag"
  }

  assert {
    condition     = aws_iam_role.cluster.tags["Environment"] == "dev"
    error_message = "Cluster role should have Environment tag"
  }

  assert {
    condition     = aws_iam_role.node.tags["Project"] == "foobar"
    error_message = "Node role should have Project tag"
  }

  assert {
    condition     = aws_iam_role.node.tags["Environment"] == "dev"
    error_message = "Node role should have Environment tag"
  }
}
