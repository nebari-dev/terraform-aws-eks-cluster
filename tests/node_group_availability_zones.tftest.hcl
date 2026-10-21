# Checks node_groups[*].availability_zones: a group restricted to some AZs gets
# only their private subnets, an unrestricted group keeps the module default, and
# AZs without a cluster private subnet are rejected. Runs against a mocked AWS
# provider, so no credentials or cloud resources are needed.

mock_provider "aws" {
  mock_data "aws_subnet" {
    defaults = {
      availability_zone = "us-west-2a"
    }
  }
}

variables {
  project_name       = "az-test"
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
  node_groups = {
    general = {
      instance = "m5.large"
    }
    user-a = {
      instance           = "m5.xlarge"
      availability_zones = ["us-west-2a"]
    }
    user-bc = {
      instance           = "m5.xlarge"
      availability_zones = ["us-west-2b", "us-west-2c"]
    }
  }
}

run "created_vpc_restricts_subnets_by_az" {
  command = plan

  plan_options {
    target = [terraform_data.node_group_availability_zones]
  }

  # Known subnet IDs for the created VPC, which are unknown at plan otherwise.
  override_module {
    target = module.vpc
    outputs = {
      private_subnets = ["subnet-a", "subnet-b", "subnet-c"]
    }
  }

  assert {
    condition     = local.node_group_subnet_ids["general"] == null
    error_message = "A group without availability_zones should not be restricted"
  }

  assert {
    condition     = local.node_group_subnet_ids["user-a"] == tolist(["subnet-a"])
    error_message = "user-a should get only the us-west-2a private subnet"
  }

  assert {
    condition     = local.node_group_subnet_ids["user-bc"] == tolist(["subnet-b", "subnet-c"])
    error_message = "user-bc should get the us-west-2b and us-west-2c private subnets"
  }

  assert {
    condition     = length(data.aws_subnet.existing_private) == 0
    error_message = "Existing subnets should not be read when the module creates the VPC"
  }
}

run "created_vpc_rejects_az_outside_cluster" {
  command = plan

  plan_options {
    target = [terraform_data.node_group_availability_zones]
  }

  variables {
    node_groups = {
      user-d = {
        instance           = "m5.xlarge"
        availability_zones = ["us-west-2d"]
      }
    }
  }

  expect_failures = [terraform_data.node_group_availability_zones]
}

# Every mocked existing subnet reports us-west-2a.
run "existing_subnets_grouped_by_az" {
  command = plan

  plan_options {
    target = [terraform_data.node_group_availability_zones]
  }

  variables {
    create_vpc                  = false
    existing_vpc_id             = "vpc-123"
    existing_private_subnet_ids = ["subnet-1", "subnet-2"]
    node_groups = {
      user-a = {
        instance           = "m5.xlarge"
        availability_zones = ["us-west-2a"]
      }
    }
  }

  assert {
    condition     = toset(local.node_group_subnet_ids["user-a"]) == toset(["subnet-1", "subnet-2"])
    error_message = "user-a should get every existing subnet in us-west-2a"
  }
}

# Subnets created in the same apply have unknown IDs at plan. Setting
# availability_zones must still plan, with the AZ check deferred to apply.
run "existing_subnets_with_unknown_ids_plan" {
  command = plan

  module {
    source = "./tests/fixtures/unknown-subnet-ids"
  }

  plan_options {
    target = [module.cluster.terraform_data.node_group_availability_zones]
  }
}

run "existing_subnets_reject_az_without_subnet" {
  command = plan

  plan_options {
    target = [terraform_data.node_group_availability_zones]
  }

  variables {
    create_vpc                  = false
    existing_vpc_id             = "vpc-123"
    existing_private_subnet_ids = ["subnet-1", "subnet-2"]
    node_groups = {
      user-b = {
        instance           = "m5.xlarge"
        availability_zones = ["us-west-2b"]
      }
    }
  }

  expect_failures = [terraform_data.node_group_availability_zones]
}

run "existing_subnets_not_read_when_unused" {
  command = plan

  plan_options {
    target = [terraform_data.node_group_availability_zones]
  }

  variables {
    create_vpc                  = false
    existing_vpc_id             = "vpc-123"
    existing_private_subnet_ids = ["subnet-1", "subnet-2"]
    node_groups = {
      general = {
        instance = "m5.large"
      }
    }
  }

  assert {
    condition     = length(data.aws_subnet.existing_private) == 0
    error_message = "Subnets should only be read when a node group sets availability_zones"
  }
}

# The valid AZ still maps to a subnet, so only the precondition catches the typo.
run "rejects_typo_next_to_valid_az" {
  command = plan

  plan_options {
    target = [terraform_data.node_group_availability_zones]
  }

  variables {
    node_groups = {
      user = {
        instance           = "m5.xlarge"
        availability_zones = ["us-west-2a", "us-west-2x"]
      }
    }
  }

  expect_failures = [terraform_data.node_group_availability_zones]
}
