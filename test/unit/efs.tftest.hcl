variables {
  project_name = "test-eks-cluster"
  node_groups = {
    test = {
      instance = "m5.large"
    }
  }
}

run "test_efs_disabled_by_default" {
  command = plan

  assert {
    condition     = length(aws_efs_file_system.main) == 0
    error_message = "EFS should not be created by default when efs_enabled=false"
  }

  assert {
    condition     = length(aws_efs_mount_target.main) == 0
    error_message = "EFS mount targets should not be created when EFS is disabled"
  }
}

run "test_efs_enabled" {
  command = plan

  variables {
    efs_enabled = true
  }

  assert {
    condition     = length(aws_efs_file_system.main) == 1
    error_message = "EFS should be created when efs_enabled=true"
  }

  assert {
    condition     = aws_efs_file_system.main[0].creation_token == "test-eks-cluster-efs"
    error_message = "EFS creation token should match cluster name"
  }
}

run "test_efs_defaults" {
  command = plan

  variables {
    efs_enabled = true
  }

  assert {
    condition     = aws_efs_file_system.main[0].performance_mode == "generalPurpose"
    error_message = "Default performance mode should be generalPurpose"
  }

  assert {
    condition     = aws_efs_file_system.main[0].throughput_mode == "bursting"
    error_message = "Default throughput mode should be bursting"
  }

  assert {
    condition     = aws_efs_file_system.main[0].encrypted == true
    error_message = "EFS should be encrypted by default"
  }
}

run "test_efs_maxio_performance" {
  command = plan

  variables {
    efs_enabled          = true
    efs_performance_mode = "maxIO"
  }

  assert {
    condition     = aws_efs_file_system.main[0].performance_mode == "maxIO"
    error_message = "Should use maxIO performance mode"
  }
}

run "test_efs_elastic_throughput" {
  command = plan

  variables {
    efs_enabled         = true
    efs_throughput_mode = "elastic"
  }

  assert {
    condition     = aws_efs_file_system.main[0].throughput_mode == "elastic"
    error_message = "Should use elastic throughput mode"
  }

  assert {
    condition     = aws_efs_file_system.main[0].provisioned_throughput_in_mibps == null
    error_message = "Provisioned throughput should be null for elastic mode"
  }
}

run "test_efs_provisioned_throughput" {
  command = plan

  variables {
    efs_enabled                         = true
    efs_throughput_mode                 = "provisioned"
    efs_provisioned_throughput_in_mibps = 100
  }

  assert {
    condition     = aws_efs_file_system.main[0].throughput_mode == "provisioned"
    error_message = "Should use provisioned throughput mode"
  }

  assert {
    condition     = aws_efs_file_system.main[0].provisioned_throughput_in_mibps == 100
    error_message = "Should set provisioned throughput to 100 MiB/s"
  }
}

run "test_efs_encryption_disabled" {
  command = plan

  variables {
    efs_enabled   = true
    efs_encrypted = false
  }

  assert {
    condition     = aws_efs_file_system.main[0].encrypted == false
    error_message = "EFS should not be encrypted when efs_encrypted=false"
  }
}

run "test_efs_custom_kms_key" {
  command = plan

  variables {
    efs_enabled    = true
    efs_encrypted  = true
    efs_kms_key_id = "arn:aws:kms:us-west-2:123456789012:key/12345678-1234-1234-1234-123456789012"
  }

  assert {
    condition     = aws_efs_file_system.main[0].encrypted == true
    error_message = "EFS should be encrypted"
  }

  assert {
    condition     = aws_efs_file_system.main[0].kms_key_id == "arn:aws:kms:us-west-2:123456789012:key/12345678-1234-1234-1234-123456789012"
    error_message = "Should use custom KMS key"
  }
}

run "test_efs_mount_targets_per_az" {
  command = plan

  variables {
    efs_enabled        = true
    availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
  }

  assert {
    condition     = length(aws_efs_mount_target.main) == 3
    error_message = "Should create one mount target per availability zone"
  }
}

run "test_efs_mount_targets_custom_security_group" {
  command = plan

  variables {
    efs_enabled                = true
    existing_security_group_id = "sg-custom123"
  }

  assert {
    condition     = contains(aws_efs_mount_target.main[0].security_groups, "sg-custom123")
    error_message = "Mount target should use custom security group when provided"
  }
}

# Test: EFS mount targets not created with existing subnets
run "test_efs_no_mount_targets_with_existing_subnets" {
  command = plan

  variables {
    efs_enabled         = true
    existing_subnet_ids = ["subnet-abc123", "subnet-def456"]
  }

  assert {
    condition     = length(aws_efs_mount_target.main) == 0
    error_message = "Mount targets should not be created when using existing subnets"
  }
}

run "test_efs_custom_tags" {
  command = plan

  variables {
    efs_enabled = true
    tags = {
      Application = "data-platform"
      Division    = "engineering"
    }
  }

  assert {
    condition     = aws_efs_file_system.main[0].tags["Application"] == "data-platform"
    error_message = "Should have Application tag"
  }

  assert {
    condition     = aws_efs_file_system.main[0].tags["Division"] == "engineering"
    error_message = "Should have Division tag"
  }
}

run "test_efs_performance_mode_invalid" {
  command = plan

  variables {
    efs_performance_mode = "invalid"
  }

  expect_failures = [
    var.efs_performance_mode,
  ]
}

run "test_efs_throughput_mode_invalid" {
  command = plan

  variables {
    efs_throughput_mode = "invalid"
  }

  expect_failures = [
    var.efs_throughput_mode,
  ]
}
