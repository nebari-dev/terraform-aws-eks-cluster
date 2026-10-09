################################################################################
# FSx for OpenZFS filesystem
################################################################################

locals {
  multi_az = var.deployment_type == "MULTI_AZ_1"
}

# The VPC may or may not have been created by the root module, so read the CIDR
# back rather than branching on create_vpc.
data "aws_vpc" "this" {
  id = var.vpc_id
}

resource "aws_security_group" "this" {
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
  for_each = {
    nfs-tcp     = { from = 2049, to = 2049, proto = "tcp" }
    portmap-tcp = { from = 111, to = 111, proto = "tcp" }
    daemons-tcp = { from = 20001, to = 20003, proto = "tcp" }
    portmap-udp = { from = 111, to = 111, proto = "udp" }
    daemons-udp = { from = 20001, to = 20003, proto = "udp" }
  }

  security_group_id            = aws_security_group.this.id
  description                  = "NFS ${each.key} from cluster nodes"
  referenced_security_group_id = var.node_security_group_id
  from_port                    = each.value.from
  to_port                      = each.value.to
  ip_protocol                  = each.value.proto
}

# Only placement and routing depend on the deployment type. SINGLE_AZ_2 runs
# one file server in the first subnet. MULTI_AZ_1 runs an active server in the
# first subnet and a standby in the second, and is reached through a floating
# endpoint IP that belongs to no subnet. FSx adds a route for that IP, pointing
# at the active server, only to the route tables it is given, so nodes in a
# subnet whose route table is missing get NFS mounts that hang. SINGLE_AZ_2 is used rather than SINGLE_AZ_1 because
# it shares MULTI_AZ_1's throughput tiers.
resource "aws_fsx_openzfs_file_system" "this" {
  deployment_type     = var.deployment_type
  storage_capacity    = var.storage_capacity
  storage_type        = "SSD"
  subnet_ids          = local.multi_az ? slice(var.subnet_ids, 0, 2) : [var.subnet_ids[0]]
  preferred_subnet_id = local.multi_az ? var.subnet_ids[0] : null
  route_table_ids     = local.multi_az ? var.route_table_ids : null
  throughput_capacity = var.throughput
  security_group_ids  = [aws_security_group.this.id]

  automatic_backup_retention_days = var.automatic_backup_retention_days
  skip_final_backup               = var.skip_final_backup
  copy_tags_to_backups            = true
  copy_tags_to_volumes            = true

  # FSx refuses to delete a filesystem that still has child volumes or
  # snapshots, which the CSI driver creates outside Terraform. Unless opted in,
  # destroy fails while any remain rather than deleting user data with them.
  delete_options = var.delete_child_volumes_on_destroy ? ["DELETE_CHILD_VOLUMES_AND_SNAPSHOTS"] : null

  root_volume_configuration {
    # The root volume is only the parent of the CSI-provisioned child volumes;
    # workloads write into children, not here.
    data_compression_type = var.compression
    nfs_exports {
      client_configurations {
        clients = data.aws_vpc.this.cidr_block
        options = ["rw", "crossmnt", "no_root_squash"]
      }
    }
  }

  tags = merge(var.tags, { Name = "${var.project_name}-fsx-openzfs" })

  lifecycle {
    precondition {
      condition     = !local.multi_az || length(var.route_table_ids) > 0
      error_message = "MULTI_AZ_1 needs route_table_ids to include the route table of every subnet the cluster nodes run in."
    }
  }
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
# Permissions start from the driver's published example policy:
# https://github.com/kubernetes-sigs/aws-fsx-openzfs-csi-driver/blob/main/docs/example-iam-policy.json
# The filesystem-level actions (Create/Update/DeleteFileSystem) and the FSx
# service-linked role statements are dropped. They are only needed when the
# driver provisions whole filesystems (ResourceType: filesystem). Here
# Terraform owns the filesystem and the driver only manages child volumes and
# snapshots under its root volume (ResourceType: volume).
module "csi_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.7.0"

  name            = "${var.project_name}-aws-fsx-openzfs-csi"
  use_name_prefix = false

  attach_custom_policy      = true
  custom_policy_description = "Permissions for the FSx for OpenZFS CSI driver"
  policy_statements = [
    {
      sid = "FSxOpenZFSVolumes"
      actions = [
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
  ]

  associations = {
    controller = {
      cluster_name    = var.cluster_name
      namespace       = "kube-system"
      service_account = "fsx-openzfs-csi-controller-sa"
    }
  }

  tags = var.tags
}
