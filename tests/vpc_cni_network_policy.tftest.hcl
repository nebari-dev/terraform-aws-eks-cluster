# Checks the configuration values passed to the vpc-cni addon. NetworkPolicy
# enforcement and policy event logs are off by default, and each variable turns
# its setting on. Runs against a mocked AWS provider, so no credentials or cloud
# resources are needed.

mock_provider "aws" {
  mock_data "aws_subnet" {
    defaults = {
      availability_zone = "us-west-2a"
    }
  }

  # Planning the cluster and its addons needs valid ARNs and policy JSON from
  # the mocks.
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

  mock_data "aws_eks_addon_version" {
    defaults = {
      version = "v1.20.0-eksbuild.1"
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
  project_name                = "netpol-test"
  create_vpc                  = false
  existing_vpc_id             = "vpc-123"
  existing_private_subnet_ids = ["subnet-a", "subnet-b"]
  node_groups = {
    general = {
      instance = "m5.large"
    }
  }
}

run "network_policy_off_by_default" {
  command = plan

  plan_options {
    target = [module.eks.aws_eks_addon.before_compute]
  }

  assert {
    condition     = jsondecode(local.vpc_cni_configuration_values).enableNetworkPolicy == "false"
    error_message = "enableNetworkPolicy should be \"false\" by default"
  }

  assert {
    condition     = jsondecode(local.vpc_cni_configuration_values).nodeAgent.enablePolicyEventLogs == "false"
    error_message = "nodeAgent.enablePolicyEventLogs should be \"false\" by default"
  }
}

run "network_policy_enabled" {
  command = plan

  plan_options {
    target = [module.eks.aws_eks_addon.before_compute]
  }

  variables {
    network_policy_enabled = true
  }

  assert {
    condition     = jsondecode(local.vpc_cni_configuration_values).enableNetworkPolicy == "true"
    error_message = "enableNetworkPolicy should be \"true\" when network_policy_enabled is true"
  }

  assert {
    condition     = jsondecode(local.vpc_cni_configuration_values).nodeAgent.enablePolicyEventLogs == "false"
    error_message = "nodeAgent.enablePolicyEventLogs should stay \"false\" unless network_policy_event_logs is true"
  }
}

run "network_policy_event_logs_enabled" {
  command = plan

  plan_options {
    target = [module.eks.aws_eks_addon.before_compute]
  }

  variables {
    network_policy_enabled    = true
    network_policy_event_logs = true
  }

  assert {
    condition     = jsondecode(local.vpc_cni_configuration_values).nodeAgent.enablePolicyEventLogs == "true"
    error_message = "nodeAgent.enablePolicyEventLogs should be \"true\" when network_policy_event_logs is true"
  }
}
