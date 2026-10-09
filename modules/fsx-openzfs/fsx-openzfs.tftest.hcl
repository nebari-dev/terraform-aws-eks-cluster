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
  route_table_ids        = ["rtb-aaaa", "rtb-bbbb", "rtb-cccc"]
  node_security_group_id = "sg-0123456789abcdef0"
}

run "multi_az_by_default" {
  command = plan

  assert {
    condition = (
      aws_fsx_openzfs_file_system.this.deployment_type == "MULTI_AZ_1" &&
      aws_fsx_openzfs_file_system.this.subnet_ids == tolist(["subnet-aaaa", "subnet-bbbb"]) &&
      aws_fsx_openzfs_file_system.this.preferred_subnet_id == "subnet-aaaa"
    )
    error_message = "The default deployment must be MULTI_AZ_1 across the first two private subnets with the first preferred."
  }

  assert {
    condition     = toset(aws_fsx_openzfs_file_system.this.route_table_ids) == toset(["rtb-aaaa", "rtb-bbbb", "rtb-cccc"])
    error_message = "Multi-AZ must route its floating endpoint through every node subnet's route table, not only the two it runs in."
  }

  assert {
    condition = (
      length(aws_vpc_security_group_ingress_rule.this) == 5 &&
      alltrue([for r in aws_vpc_security_group_ingress_rule.this : r.referenced_security_group_id == "sg-0123456789abcdef0"])
    )
    error_message = "NFS security group must open all five NFS/OpenZFS port rules to the node security group."
  }

  assert {
    condition     = [for c in aws_fsx_openzfs_file_system.this.root_volume_configuration[0].nfs_exports[0].client_configurations : c.clients] == ["10.10.0.0/16"]
    error_message = "NFS exports must be scoped to the VPC CIDR."
  }
}

run "single_az" {
  command = plan

  variables {
    deployment_type = "SINGLE_AZ_2"
  }

  assert {
    condition = (
      aws_fsx_openzfs_file_system.this.deployment_type == "SINGLE_AZ_2" &&
      aws_fsx_openzfs_file_system.this.subnet_ids == tolist(["subnet-aaaa"]) &&
      aws_fsx_openzfs_file_system.this.preferred_subnet_id == null
    )
    error_message = "SINGLE_AZ_2 must be placed in the first private subnet only."
  }
}

run "rejects_unknown_deployment_type" {
  command = plan

  variables {
    deployment_type = "SINGLE_AZ_1"
  }

  expect_failures = [var.deployment_type]
}

run "multi_az_requires_route_tables" {
  command = plan

  variables {
    route_table_ids = []
  }

  expect_failures = [aws_fsx_openzfs_file_system.this]
}
