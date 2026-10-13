# Checks the ebs_csi_kms_key_arns input: KMS key ARNs are accepted, alias ARNs
# and bare key IDs are rejected. Plans only the EBS CSI pod-identity module
# against a mocked AWS provider, so no credentials or cloud resources are needed.

mock_provider "aws" {
  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::123456789012:policy/mock"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  project_name = "kms-test"
  node_groups = {
    general = {
      instance = "m5.large"
    }
  }
}

run "no_keys_by_default" {
  command = plan

  plan_options {
    target = [module.ebs_csi_pod_identity]
  }

  assert {
    condition     = length(var.ebs_csi_kms_key_arns) == 0
    error_message = "ebs_csi_kms_key_arns should default to an empty list"
  }
}

run "accepts_key_arns" {
  command = plan

  plan_options {
    target = [module.ebs_csi_pod_identity]
  }

  variables {
    ebs_csi_kms_key_arns = [
      "arn:aws:kms:us-east-1:123456789012:key/1234abcd-12ab-34cd-56ef-1234567890ab",
      "arn:aws-us-gov:kms:us-gov-west-1:123456789012:key/mrk-1234abcd12ab34cd56ef1234567890ab",
    ]
  }
}

run "rejects_alias_arn" {
  command = plan

  plan_options {
    target = [module.ebs_csi_pod_identity]
  }

  variables {
    ebs_csi_kms_key_arns = ["arn:aws:kms:us-east-1:123456789012:alias/ebs-default"]
  }

  expect_failures = [var.ebs_csi_kms_key_arns]
}

run "rejects_bare_key_id" {
  command = plan

  plan_options {
    target = [module.ebs_csi_pod_identity]
  }

  variables {
    ebs_csi_kms_key_arns = ["1234abcd-12ab-34cd-56ef-1234567890ab"]
  }

  expect_failures = [var.ebs_csi_kms_key_arns]
}
