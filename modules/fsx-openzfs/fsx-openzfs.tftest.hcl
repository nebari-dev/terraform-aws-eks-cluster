# Plan-only tests against a mocked AWS provider, so they need no credentials.
# The mocks only stand in for data source lookups; assertions are about which
# resources the module plans and how they are wired.

mock_provider "aws" {
  mock_data "aws_vpc" {
    defaults = {
      cidr_block = "10.10.0.0/16"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  # Mocked computed values are random strings by default, which the provider's
  # ARN validation rejects when they are passed on to the Pod Identity module.
  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::123456789012:policy/fsx-test-aws-fsx-openzfs-csi"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/fsx-test-aws-fsx-openzfs-csi"
    }
  }
}

variables {
  project_name           = "fsx-test"
  cluster_name           = "fsx-test"
  vpc_id                 = "vpc-0123456789abcdef0"
  subnet_ids             = ["subnet-aaaa", "subnet-bbbb", "subnet-cccc"]
  node_security_group_id = "sg-0123456789abcdef0"
}

run "disabled_creates_nothing" {
  command = plan

  assert {
    condition = (
      length(aws_fsx_openzfs_file_system.single_az) == 0 &&
      length(aws_fsx_openzfs_file_system.multi_az) == 0 &&
      length(aws_security_group.this) == 0 &&
      length(aws_vpc_security_group_ingress_rule.this) == 0 &&
      length(aws_iam_policy.csi) == 0 &&
      length(module.csi_pod_identity) == 0 &&
      length(data.aws_route_table.this) == 0
    )
    error_message = "With both deployment types disabled the module must plan no filesystems, security group, IAM or Pod Identity."
  }

  assert {
    condition = (
      output.single_az_id == "" && output.single_az_dns_name == "" && output.single_az_root_volume_id == "" &&
      output.multi_az_id == "" && output.multi_az_dns_name == "" && output.multi_az_root_volume_id == ""
    )
    error_message = "Disabled filesystems must surface as empty strings, which is what NIC checks for."
  }
}

run "single_az_only" {
  command = plan

  variables {
    single_az_enabled = true
  }

  assert {
    condition     = length(aws_fsx_openzfs_file_system.single_az) == 1 && length(aws_fsx_openzfs_file_system.multi_az) == 0
    error_message = "single_az_enabled alone must plan exactly the Single-AZ filesystem."
  }

  assert {
    condition     = aws_fsx_openzfs_file_system.single_az[0].deployment_type == "SINGLE_AZ_2"
    error_message = "Single-AZ must use SINGLE_AZ_2 so its throughput tiers line up with MULTI_AZ_1."
  }

  assert {
    condition     = aws_fsx_openzfs_file_system.single_az[0].subnet_ids == tolist(["subnet-aaaa"])
    error_message = "Single-AZ must be placed in the first private subnet."
  }

  assert {
    condition     = [for c in aws_fsx_openzfs_file_system.single_az[0].root_volume_configuration[0].nfs_exports[0].client_configurations : c.clients] == ["10.10.0.0/16"]
    error_message = "NFS exports must be scoped to the VPC CIDR."
  }

  assert {
    condition     = length(data.aws_route_table.this) == 0
    error_message = "Route table lookups are only needed for Multi-AZ."
  }

  assert {
    condition = (
      length(aws_security_group.this) == 1 &&
      length(aws_vpc_security_group_ingress_rule.this) == 5 &&
      alltrue([for r in aws_vpc_security_group_ingress_rule.this : r.referenced_security_group_id == "sg-0123456789abcdef0"])
    )
    error_message = "NFS security group must open all five NFS/OpenZFS port rules to the node security group."
  }

  assert {
    condition     = length(aws_iam_policy.csi) == 1 && length(module.csi_pod_identity) == 1
    error_message = "Any enabled filesystem needs the CSI controller's IAM policy and Pod Identity."
  }

  assert {
    condition     = output.multi_az_id == "" && output.multi_az_dns_name == "" && output.multi_az_root_volume_id == ""
    error_message = "Disabled Multi-AZ outputs must be empty strings."
  }
}

run "both_enabled" {
  command = plan

  variables {
    single_az_enabled = true
    multi_az_enabled  = true
  }

  assert {
    condition     = length(aws_fsx_openzfs_file_system.single_az) == 1 && length(aws_fsx_openzfs_file_system.multi_az) == 1
    error_message = "Both flags must plan both filesystems."
  }

  assert {
    condition = (
      aws_fsx_openzfs_file_system.multi_az[0].deployment_type == "MULTI_AZ_1" &&
      aws_fsx_openzfs_file_system.multi_az[0].subnet_ids == tolist(["subnet-aaaa", "subnet-bbbb"]) &&
      aws_fsx_openzfs_file_system.multi_az[0].preferred_subnet_id == "subnet-aaaa"
    )
    error_message = "Multi-AZ must span the first two private subnets with the first preferred."
  }

  assert {
    condition     = length(data.aws_route_table.this) == 2
    error_message = "Multi-AZ must resolve the route tables of both of its subnets for the floating endpoint."
  }

  assert {
    condition     = length(aws_security_group.this) == 1 && length(aws_iam_policy.csi) == 1 && length(module.csi_pod_identity) == 1
    error_message = "The security group, IAM policy and Pod Identity are shared, not duplicated per filesystem."
  }
}
