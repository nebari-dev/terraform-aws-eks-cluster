# Checks the control plane subnets passed to the EKS module. Empty makes the
# EKS module use the node subnets, so that is the default with an existing VPC,
# and existing_control_plane_subnet_ids is passed through when set.
# Runs against a mocked AWS provider, so no credentials or cloud resources
# are needed.

mock_provider "aws" {
  # Planning the cluster needs valid ARNs and policy JSON from the mocks.
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/test"
    }
  }

  mock_data "aws_iam_session_context" {
    defaults = {
      issuer_arn = "arn:aws:iam::123456789012:user/test"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{}"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/test"
    }
  }

  mock_resource "aws_kms_key" {
    defaults = {
      arn = "arn:aws:kms:us-west-2:123456789012:key/test"
    }
  }
}

variables {
  project_name                = "cp-test"
  create_vpc                  = false
  existing_vpc_id             = "vpc-123"
  existing_private_subnet_ids = ["subnet-a"]
  node_groups = {
    general = {
      instance = "m5.large"
    }
  }
}

run "defaults_to_node_subnets" {
  command = plan

  plan_options {
    target = [module.eks.aws_eks_cluster.this]
  }

  variables {
    existing_private_subnet_ids = ["subnet-a", "subnet-b"]
  }

  assert {
    condition     = length(local.control_plane_subnet_ids) == 0
    error_message = "No control plane subnets should be passed when existing_control_plane_subnet_ids is empty, so the node subnets are used"
  }
}

run "uses_control_plane_subnets_when_set" {
  command = plan

  plan_options {
    target = [module.eks.aws_eks_cluster.this]
  }

  variables {
    existing_control_plane_subnet_ids = ["subnet-a", "subnet-b"]
  }

  assert {
    condition     = local.control_plane_subnet_ids == tolist(["subnet-a", "subnet-b"])
    error_message = "existing_control_plane_subnet_ids should be passed as the control plane subnets"
  }
}

run "created_vpc_ignores_control_plane_subnets" {
  command = plan

  plan_options {
    target = [module.eks.aws_eks_cluster.this]
  }

  variables {
    create_vpc                        = true
    availability_zones                = ["us-west-2a", "us-west-2b"]
    existing_control_plane_subnet_ids = ["subnet-x", "subnet-y"]
  }

  # Known subnet IDs for the created VPC, which are unknown at plan otherwise.
  override_module {
    target = module.vpc
    outputs = {
      vpc_id          = "vpc-created"
      private_subnets = ["subnet-1", "subnet-2"]
    }
  }

  assert {
    condition     = length(local.control_plane_subnet_ids) == 0
    error_message = "existing_control_plane_subnet_ids should be ignored when the module creates the VPC"
  }
}
