data "aws_partition" "current" {}

################################################################################
# FSx for OpenZFS filesystems (optional)
################################################################################
# Both deployment types can be enabled at once. That is wasteful for production
# but is exactly what a benchmark needs: Multi-AZ acknowledges writes across
# AZs, so Single-AZ numbers do not substitute for Multi-AZ ones.

locals {
  enabled = var.single_az_enabled || var.multi_az_enabled
}

# The VPC may or may not have been created by the root module, so read the CIDR
# back rather than branching on create_vpc.
data "aws_vpc" "this" {
  count = local.enabled ? 1 : 0
  id    = var.vpc_id
}

# Multi-AZ reaches clients through a floating endpoint whose routes are
# injected into the subnets' route tables. Only subnet IDs are passed in, so
# resolve the route tables from the first two of them. Counted by index rather
# than for_each over the IDs so plan still works when the subnets are created
# in the same apply and their IDs are not yet known.
data "aws_route_table" "this" {
  count     = var.multi_az_enabled ? 2 : 0
  subnet_id = var.subnet_ids[count.index]
}

resource "aws_security_group" "this" {
  count = local.enabled ? 1 : 0

  name        = "${var.project_name}-fsx-openzfs"
  description = "NFS access to FSx for OpenZFS from cluster nodes"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.project_name}-fsx-openzfs" })
}

# 111/2049 for NFS itself, 20001-20003 for the OpenZFS mount/status/lock
# daemons. Missing the high ports gives mounts that hang rather than fail,
# which is a slow thing to debug. Source is the node security group, so this
# does not depend on the VPC CIDR shape.
resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = local.enabled ? {
    nfs-tcp     = { from = 2049, to = 2049, proto = "tcp" }
    portmap-tcp = { from = 111, to = 111, proto = "tcp" }
    daemons-tcp = { from = 20001, to = 20003, proto = "tcp" }
    portmap-udp = { from = 111, to = 111, proto = "udp" }
    daemons-udp = { from = 20001, to = 20003, proto = "udp" }
  } : {}

  security_group_id            = aws_security_group.this[0].id
  description                  = "NFS ${each.key} from cluster nodes"
  referenced_security_group_id = var.node_security_group_id
  from_port                    = each.value.from
  to_port                      = each.value.to
  ip_protocol                  = each.value.proto
}

resource "aws_fsx_openzfs_file_system" "single_az" {
  count = var.single_az_enabled ? 1 : 0

  # SINGLE_AZ_2 rather than SINGLE_AZ_1: its throughput tiers (160, 320, ...)
  # line up with MULTI_AZ_1's, so the two deployment types can be given
  # identical provisioned throughput and the comparison isolates the write
  # path instead of confounding it with a different throughput floor.
  deployment_type     = "SINGLE_AZ_2"
  storage_capacity    = var.storage_capacity
  storage_type        = "SSD"
  subnet_ids          = [var.subnet_ids[0]]
  throughput_capacity = var.throughput
  security_group_ids  = [aws_security_group.this[0].id]
  skip_final_backup   = true

  root_volume_configuration {
    # The root volume is only the parent of the CSI-provisioned child volumes;
    # workloads write into children, not here.
    data_compression_type = var.compression
    nfs_exports {
      client_configurations {
        clients = data.aws_vpc.this[0].cidr_block
        options = ["rw", "crossmnt", "no_root_squash"]
      }
    }
  }

  tags = merge(var.tags, { Name = "${var.project_name}-fsx-openzfs-single-az" })
}

resource "aws_fsx_openzfs_file_system" "multi_az" {
  count = var.multi_az_enabled ? 1 : 0

  deployment_type     = "MULTI_AZ_1"
  storage_capacity    = var.storage_capacity
  storage_type        = "SSD"
  subnet_ids          = slice(var.subnet_ids, 0, 2)
  preferred_subnet_id = var.subnet_ids[0]
  route_table_ids     = distinct(data.aws_route_table.this[*].route_table_id)
  throughput_capacity = var.throughput
  security_group_ids  = [aws_security_group.this[0].id]
  skip_final_backup   = true

  root_volume_configuration {
    data_compression_type = var.compression
    nfs_exports {
      client_configurations {
        clients = data.aws_vpc.this[0].cidr_block
        options = ["rw", "crossmnt", "no_root_squash"]
      }
    }
  }

  tags = merge(var.tags, { Name = "${var.project_name}-fsx-openzfs-multi-az" })
}

################################################################################
# FSx for OpenZFS CSI controller Pod Identity
################################################################################
# The root module wires an EKS Pod Identity association for the EFS CSI driver,
# but FSx is not one of its supported addons, so the equivalent is built here.
# Without it the controller falls back to IMDS, finds no role, and every PVC
# fails with "no EC2 IMDS role found". The CSI driver itself is installed by
# the consumer (e.g. Nebari Infrastructure Core); only its IAM lives here.
#
# Permissions follow the driver's published example policy:
# https://github.com/kubernetes-sigs/aws-fsx-openzfs-csi-driver/blob/main/docs/example-iam-policy.json

data "aws_iam_policy_document" "csi" {
  count = local.enabled ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole",
      "iam:AttachRolePolicy",
      "iam:PutRolePolicy",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:iam::*:role/aws-service-role/fsx.amazonaws.com/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "iam:AWSServiceName"
      values   = ["fsx.amazonaws.com"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "fsx:CreateFileSystem",
      "fsx:UpdateFileSystem",
      "fsx:DeleteFileSystem",
      "fsx:DescribeFileSystems",
      "fsx:CreateVolume",
      "fsx:DeleteVolume",
      "fsx:DescribeVolumes",
      "fsx:CreateSnapshot",
      "fsx:DeleteSnapshot",
      "fsx:DescribeSnapshots",
      "fsx:TagResource",
      "fsx:ListTagsForResource",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "csi" {
  count = local.enabled ? 1 : 0

  name        = "${var.project_name}-aws-fsx-openzfs-csi"
  description = "Permissions for the FSx for OpenZFS CSI driver"
  policy      = data.aws_iam_policy_document.csi[0].json
  tags        = var.tags
}

module "csi_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.7.0"

  count = local.enabled ? 1 : 0

  name            = "${var.project_name}-aws-fsx-openzfs-csi"
  use_name_prefix = false

  additional_policy_arns = {
    fsx_csi = aws_iam_policy.csi[0].arn
  }

  associations = {
    controller = {
      cluster_name    = var.cluster_name
      namespace       = "kube-system"
      service_account = "fsx-openzfs-csi-controller-sa"
    }
  }

  tags = var.tags
}
