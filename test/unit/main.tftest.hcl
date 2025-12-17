variables {
  project_name = "test-eks-cluster"
  node_groups = {
    test = {
      instance = "m5.large"
    }
  }
}

run "test_eks_cluster_name" {
  command = plan

  assert {
    condition     = aws_eks_cluster.main.name == "test-eks-cluster"
    error_message = "Cluster name should match project_name"
  }
}

run "test_eks_cluster_custom_version" {
  command = plan

  variables {
    kubernetes_version = "1.28"
  }

  assert {
    condition     = aws_eks_cluster.main.version == "1.28"
    error_message = "Cluster should use specified Kubernetes version"
  }
}

run "test_eks_endpoint_private" {
  command = plan

  variables {
    eks_endpoint_access = "private"
  }

  assert {
    condition     = aws_eks_cluster.main.vpc_config[0].endpoint_private_access == true
    error_message = "Private access should be enabled"
  }

  assert {
    condition     = aws_eks_cluster.main.vpc_config[0].endpoint_public_access == false
    error_message = "Public access should be disabled"
  }
}

run "test_eks_endpoint_public" {
  command = plan

  variables {
    eks_endpoint_access = "public"
  }

  assert {
    condition     = aws_eks_cluster.main.vpc_config[0].endpoint_private_access == false
    error_message = "Private access should be disabled"
  }

  assert {
    condition     = aws_eks_cluster.main.vpc_config[0].endpoint_public_access == true
    error_message = "Public access should be enabled"
  }
}

run "test_eks_endpoint_public_and_private" {
  command = plan

  variables {
    eks_endpoint_access = "public-and-private"
  }

  assert {
    condition     = aws_eks_cluster.main.vpc_config[0].endpoint_private_access == true
    error_message = "Private access should be enabled"
  }

  assert {
    condition     = aws_eks_cluster.main.vpc_config[0].endpoint_public_access == true
    error_message = "Public access should be enabled"
  }
}

run "test_eks_endpoint_access_invalid" {
  command = plan

  variables {
    eks_endpoint_access = "invalid"
  }

  expect_failures = [
    var.eks_endpoint_access,
  ]
}

run "test_eks_public_access_cidrs" {
  command = plan

  variables {
    eks_endpoint_access     = "public"
    eks_public_access_cidrs = ["1.2.3.4/32", "5.6.7.8/32"]
  }

  assert {
    condition     = length(aws_eks_cluster.main.vpc_config[0].public_access_cidrs) == 2
    error_message = "Should have 2 public access CIDRs"
  }

  assert {
    condition     = contains(aws_eks_cluster.main.vpc_config[0].public_access_cidrs, "1.2.3.4/32")
    error_message = "Should contain first CIDR"
  }
}

run "test_eks_encryption_enabled" {
  command = plan

  variables {
    eks_kms_arn = "arn:aws:kms:us-west-2:123456789012:key/12345678-1234-1234-1234-123456789012"
  }

  assert {
    condition     = length(aws_eks_cluster.main.encryption_config) == 1
    error_message = "Encryption config should be set when KMS ARN is provided"
  }

  assert {
    condition     = aws_eks_cluster.main.encryption_config[0].provider[0].key_arn == "arn:aws:kms:us-west-2:123456789012:key/12345678-1234-1234-1234-123456789012"
    error_message = "Should use provided KMS key ARN"
  }

  assert {
    condition     = contains(aws_eks_cluster.main.encryption_config[0].resources, "secrets")
    error_message = "Should encrypt secrets"
  }
}

run "test_eks_no_encryption_by_default" {
  command = plan

  assert {
    condition     = length(aws_eks_cluster.main.encryption_config) == 0
    error_message = "Encryption config should not be set by default"
  }
}

run "test_eks_logging_default" {
  command = plan

  assert {
    condition     = length(aws_eks_cluster.main.enabled_cluster_log_types) == 1
    error_message = "Should have 1 log type enabled by default"
  }

  assert {
    condition     = contains(aws_eks_cluster.main.enabled_cluster_log_types, "authenticator")
    error_message = "Authenticator logging should be enabled by default"
  }
}

run "test_eks_logging_multiple" {
  command = plan

  variables {
    cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  }

  assert {
    condition     = length(aws_eks_cluster.main.enabled_cluster_log_types) == 5
    error_message = "Should have all 5 log types enabled"
  }

  assert {
    condition     = contains(aws_eks_cluster.main.enabled_cluster_log_types, "api")
    error_message = "Should include api logs"
  }

  assert {
    condition     = contains(aws_eks_cluster.main.enabled_cluster_log_types, "audit")
    error_message = "Should include audit logs"
  }
}

run "test_cluster_log_types_invalid" {
  command = plan

  variables {
    cluster_enabled_log_types = ["api", "invalid_type"]
  }

  expect_failures = [
    var.cluster_enabled_log_types,
  ]
}

run "test_eks_uses_existing_subnets" {
  command = plan

  variables {
    existing_subnet_ids = ["subnet-abc123", "subnet-def456"]
  }

  assert {
    condition     = contains(aws_eks_cluster.main.vpc_config[0].subnet_ids, "subnet-abc123")
    error_message = "Should use provided existing subnet"
  }

  assert {
    condition     = length(aws_eks_cluster.main.vpc_config[0].subnet_ids) == 2
    error_message = "Should use all provided existing subnets"
  }
}

run "test_eks_custom_security_group" {
  command = plan

  variables {
    existing_security_group_id = "sg-custom123"
  }

  assert {
    condition     = contains(aws_eks_cluster.main.vpc_config[0].security_group_ids, "sg-custom123")
    error_message = "Should use custom security group when provided"
  }
}

run "test_eks_custom_tags" {
  command = plan

  variables {
    tags = {
      Environment = "test"
      ManagedBy   = "terraform"
    }
  }

  assert {
    condition     = aws_eks_cluster.main.tags["Environment"] == "test"
    error_message = "Should have Environment tag"
  }

  assert {
    condition     = aws_eks_cluster.main.tags["ManagedBy"] == "terraform"
    error_message = "Should have ManagedBy tag"
  }
}

run "test_single_node_group" {
  command = plan

  variables {
    node_groups = {
      general = {
        instance  = "m5.large"
        min_nodes = 1
        max_nodes = 3
      }
    }
  }

  assert {
    condition     = length(aws_eks_node_group.main) == 1
    error_message = "Should create exactly 1 node group"
  }

  assert {
    condition     = aws_eks_node_group.main["general"].node_group_name == "general"
    error_message = "Node group name should match key"
  }
}

run "test_multiple_node_groups" {
  command = plan

  variables {
    node_groups = {
      general = {
        instance = "m5.large"
      }
      compute = {
        instance = "c5.xlarge"
      }
      memory = {
        instance = "r5.xlarge"
      }
    }
  }

  assert {
    condition     = length(aws_eks_node_group.main) == 3
    error_message = "Should create 3 node groups"
  }

  assert {
    condition     = aws_eks_node_group.main["general"].instance_types[0] == "m5.large"
    error_message = "General node group should use m5.large"
  }

  assert {
    condition     = aws_eks_node_group.main["compute"].instance_types[0] == "c5.xlarge"
    error_message = "Compute node group should use c5.xlarge"
  }

  assert {
    condition     = aws_eks_node_group.main["memory"].instance_types[0] == "r5.xlarge"
    error_message = "Memory node group should use r5.xlarge"
  }
}

run "test_node_group_scaling" {
  command = plan

  variables {
    node_groups = {
      scalable = {
        instance  = "m5.large"
        min_nodes = 2
        max_nodes = 10
      }
    }
  }

  assert {
    condition     = aws_eks_node_group.main["scalable"].scaling_config[0].min_size == 2
    error_message = "Min size should be 2"
  }

  assert {
    condition     = aws_eks_node_group.main["scalable"].scaling_config[0].max_size == 10
    error_message = "Max size should be 10"
  }

  assert {
    condition     = aws_eks_node_group.main["scalable"].scaling_config[0].desired_size == 2
    error_message = "Desired size should match min_nodes"
  }
}

run "test_node_group_defaults" {
  command = plan

  variables {
    node_groups = {
      minimal = {
        instance = "t3.medium"
      }
    }
  }

  assert {
    condition     = aws_eks_node_group.main["minimal"].scaling_config[0].min_size == 0
    error_message = "Default min_nodes should be 0"
  }

  assert {
    condition     = aws_eks_node_group.main["minimal"].scaling_config[0].max_size == 1
    error_message = "Default max_nodes should be 1"
  }

  assert {
    condition     = aws_eks_node_group.main["minimal"].capacity_type == "ON_DEMAND"
    error_message = "Default capacity type should be ON_DEMAND"
  }

  assert {
    condition     = aws_eks_node_group.main["minimal"].ami_type == "AL2023_x86_64_STANDARD"
    error_message = "Default AMI type should be AL2023_x86_64_STANDARD"
  }
}

run "test_node_group_spot" {
  command = plan

  variables {
    node_groups = {
      spot = {
        instance = "m5.large"
        spot     = true
      }
    }
  }

  assert {
    condition     = aws_eks_node_group.main["spot"].capacity_type == "SPOT"
    error_message = "Should use SPOT capacity when spot=true"
  }
}

run "test_node_group_gpu" {
  command = plan

  variables {
    node_groups = {
      gpu = {
        instance = "p3.2xlarge"
        gpu      = true
      }
    }
  }

  assert {
    condition     = aws_eks_node_group.main["gpu"].ami_type == "AL2023_x86_64_NVIDIA"
    error_message = "Should automatically use NVIDIA AMI when gpu=true"
  }
}

run "test_node_group_custom_ami" {
  command = plan

  variables {
    node_groups = {
      arm = {
        instance = "m6g.large"
        ami_type = "AL2023_ARM_64_STANDARD"
      }
    }
  }

  assert {
    condition     = aws_eks_node_group.main["arm"].ami_type == "AL2023_ARM_64_STANDARD"
    error_message = "Should use custom AMI type when specified"
  }
}

run "test_node_group_custom_disk_size" {
  command = plan

  variables {
    node_groups = {
      large_disk = {
        instance  = "m5.large"
        disk_size = 100
      }
    }
  }

  assert {
    condition     = aws_eks_node_group.main["large_disk"].disk_size == 100
    error_message = "Should use custom disk size"
  }
}

run "test_node_group_with_taints" {
  command = plan

  variables {
    node_groups = {
      tainted = {
        instance = "g4ad.xlarge"
        taints = [
          {
            key    = "workload"
            value  = "ml"
            effect = "NO_SCHEDULE"
          },
          {
            key    = "gpu"
            value  = "true"
            effect = "PREFER_NO_SCHEDULE"
          }
        ]
      }
    }
  }

  assert {
    condition     = length(aws_eks_node_group.main["tainted"].taint) == 2
    error_message = "Should have 2 taints"
  }

  assert {
    condition     = contains([for t in aws_eks_node_group.main["tainted"].taint : t.key], "workload")
    error_message = "Should have taint with key 'workload'"
  }

  assert {
    condition     = contains([for t in aws_eks_node_group.main["tainted"].taint : t.key], "gpu")
    error_message = "Should have taint with key 'gpu'"
  }

  assert {
    condition = alltrue([
      for t in aws_eks_node_group.main["tainted"].taint :
      t.key == "workload" ? t.effect == "NO_SCHEDULE" : true
    ])
    error_message = "Workload taint should have NO_SCHEDULE effect"
  }

  assert {
    condition = alltrue([
      for t in aws_eks_node_group.main["tainted"].taint :
      t.key == "gpu" ? t.effect == "PREFER_NO_SCHEDULE" : true
    ])
    error_message = "GPU taint should have PREFER_NO_SCHEDULE effect"
  }
}

run "test_node_group_labels" {
  command = plan

  variables {
    node_groups = {
      labeled = {
        instance = "m5.large"
      }
    }
  }

  assert {
    condition     = aws_eks_node_group.main["labeled"].labels["node-group"] == "labeled"
    error_message = "Should have node-group label matching the node group name"
  }
}

run "test_node_group_custom_tags" {
  command = plan

  variables {
    tags = {
      Project       = "foobar"
      Environment = "prod"
    }
    node_groups = {
      test = {
        instance = "m5.large"
      }
    }
  }

  assert {
    condition     = aws_eks_node_group.main["test"].tags["Project"] == "foobar"
    error_message = "Should have Project tag"
  }

  assert {
    condition     = aws_eks_node_group.main["test"].tags["Environment"] == "prod"
    error_message = "Should have Environment tag"
  }
}

run "test_node_groups_empty_invalid" {
  command = plan

  variables {
    project_name = "test-cluster"
    node_groups  = {}
  }

  expect_failures = [
    var.node_groups,
  ]
}

run "test_node_groups_min_greater_than_max_invalid" {
  command = plan

  variables {
    node_groups = {
      test = {
        instance  = "m5.large"
        min_nodes = 5
        max_nodes = 2
      }
    }
  }

  expect_failures = [
    var.node_groups,
  ]
}

run "test_node_groups_negative_min_invalid" {
  command = plan

  variables {
    node_groups = {
      test = {
        instance  = "m5.large"
        min_nodes = -1
      }
    }
  }

  expect_failures = [
    var.node_groups,
  ]
}

run "test_node_groups_invalid_taint_effect" {
  command = plan

  variables {
    node_groups = {
      test = {
        instance = "m5.large"
        taints = [
          {
            key    = "gpu"
            value  = "true"
            effect = "INVALID_EFFECT"
          }
        ]
      }
    }
  }

  expect_failures = [
    var.node_groups,
  ]
}
