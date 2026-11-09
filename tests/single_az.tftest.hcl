# Checks a created VPC with one AZ: the VPC module also gets a private subnet in a
# second AZ for the control plane only, while public subnets, NAT, endpoints, EFS and
# the internal load balancer tag stay in the node AZ. Also checks that two or more
# AZs keep today's layout. Runs against a mocked AWS provider, so no credentials or
# cloud resources are needed.

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-west-2a", "us-west-2b", "us-west-2c", "us-west-2d"]
    }
  }

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
  project_name       = "single-az-test"
  availability_zones = ["us-west-2c"]
  efs_enabled        = true
  node_groups = {
    general = {
      instance = "m5.large"
    }
  }
}

run "single_az_vpc_layout" {
  command = plan

  plan_options {
    target = [module.vpc]
  }

  assert {
    condition     = output.control_plane_availability_zone == "us-west-2a"
    error_message = "The control plane AZ should be the first other AZ, sorted by name"
  }

  assert {
    condition     = module.vpc[0].azs == tolist(["us-west-2c", "us-west-2a"])
    error_message = "The VPC module should get the node AZ followed by the control plane AZ"
  }

  assert {
    condition     = length(module.vpc[0].private_subnet_objects) == 2
    error_message = "There should be a private subnet in the node AZ and one in the control plane AZ"
  }

  assert {
    condition     = length(module.vpc[0].public_subnets) == 1
    error_message = "There should be a public subnet in the node AZ only"
  }

  assert {
    condition     = length(module.vpc[0].natgw_ids) == 1
    error_message = "There should be a single NAT gateway"
  }

  assert {
    condition     = module.vpc[0].private_subnet_objects[0].tags["kubernetes.io/role/internal-elb"] == "1"
    error_message = "The node AZ private subnet should have the internal load balancer tag"
  }

  assert {
    condition     = !contains(keys(module.vpc[0].private_subnet_objects[1].tags), "kubernetes.io/role/internal-elb")
    error_message = "The control-plane-only subnet should not have the internal load balancer tag"
  }
}

run "single_az_subnet_wiring" {
  command = plan

  plan_options {
    target = [module.eks.aws_eks_cluster.this, module.efs, module.vpc_endpoints]
  }

  # Known subnet IDs for the created VPC, which are unknown at plan otherwise.
  override_module {
    target = module.vpc
    outputs = {
      vpc_id                  = "vpc-created"
      private_subnets         = ["subnet-node", "subnet-cp"]
      public_subnets          = ["subnet-public"]
      private_route_table_ids = ["rtb-private"]
      public_route_table_ids  = ["rtb-public"]
    }
  }

  assert {
    condition     = local.private_subnet_ids == tolist(["subnet-node"])
    error_message = "Nodes, endpoints, EFS and FSx should only get the node AZ subnet"
  }

  assert {
    condition     = local.control_plane_subnet_ids == tolist(["subnet-node", "subnet-cp"])
    error_message = "The control plane should get both private subnets"
  }

  assert {
    condition     = keys(local.efs_mount_targets) == tolist(["0"])
    error_message = "EFS should only get a mount target in the node AZ subnet"
  }
}

run "single_az_rejects_node_group_in_control_plane_az" {
  command = plan

  plan_options {
    target = [terraform_data.node_group_availability_zones]
  }

  variables {
    node_groups = {
      user = {
        instance           = "m5.xlarge"
        availability_zones = ["us-west-2a"]
      }
    }
  }

  expect_failures = [terraform_data.node_group_availability_zones]
}

run "multi_az_vpc_layout_unchanged" {
  command = plan

  plan_options {
    target = [module.vpc]
  }

  variables {
    availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
  }

  assert {
    condition     = output.control_plane_availability_zone == null
    error_message = "There should be no control plane AZ with more than one AZ"
  }

  assert {
    condition     = length(data.aws_availability_zones.control_plane) == 0
    error_message = "The control plane AZ candidates should only be read with one AZ"
  }

  assert {
    condition     = module.vpc[0].azs == tolist(["us-west-2a", "us-west-2b", "us-west-2c"])
    error_message = "The VPC module should get the AZs as given"
  }

  assert {
    condition     = length(module.vpc[0].natgw_ids) == 3
    error_message = "There should be one NAT gateway per AZ"
  }

  assert {
    condition     = alltrue([for subnet in module.vpc[0].private_subnet_objects : subnet.tags["kubernetes.io/role/internal-elb"] == "1"])
    error_message = "Every private subnet should have the internal load balancer tag"
  }
}

run "multi_az_subnet_wiring_unchanged" {
  command = plan

  plan_options {
    target = [module.eks.aws_eks_cluster.this, module.vpc_endpoints]
  }

  variables {
    availability_zones = ["us-west-2a", "us-west-2b"]
  }

  override_module {
    target = module.vpc
    outputs = {
      vpc_id                  = "vpc-created"
      private_subnets         = ["subnet-a", "subnet-b"]
      public_subnets          = ["subnet-public-a", "subnet-public-b"]
      private_route_table_ids = ["rtb-a", "rtb-b"]
      public_route_table_ids  = ["rtb-public"]
    }
  }

  assert {
    condition     = local.private_subnet_ids == tolist(["subnet-a", "subnet-b"])
    error_message = "Every private subnet should be a node subnet"
  }

  assert {
    condition     = length(local.control_plane_subnet_ids) == 0
    error_message = "No control plane subnets should be passed, so the control plane uses the node subnets"
  }
}
