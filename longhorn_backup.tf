################################################################################
# Longhorn backup bucket (optional)
################################################################################
# Optional S3 bucket for Longhorn off-cluster backups. Disabled by default;
# enabled by consumers (e.g. Nebari Infrastructure Core) that schedule Longhorn
# snapshots/backups to S3. When longhorn_backup_bucket_force_destroy is false
# (the default), `terraform destroy` refuses to delete a non-empty bucket,
# protecting existing backups.

resource "aws_s3_bucket" "longhorn_backup" {
  count         = var.longhorn_backup_bucket_create ? 1 : 0
  bucket        = var.longhorn_backup_bucket_name
  force_destroy = var.longhorn_backup_bucket_force_destroy
  tags          = var.tags
}

resource "aws_s3_bucket_versioning" "longhorn_backup" {
  count  = var.longhorn_backup_bucket_create ? 1 : 0
  bucket = aws_s3_bucket.longhorn_backup[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "longhorn_backup" {
  count  = var.longhorn_backup_bucket_create ? 1 : 0
  bucket = aws_s3_bucket.longhorn_backup[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "longhorn_backup" {
  count  = var.longhorn_backup_bucket_create ? 1 : 0
  bucket = aws_s3_bucket.longhorn_backup[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

################################################################################
# Longhorn backup Pod Identity (optional, keyless S3 auth)
################################################################################
# Grants Longhorn's service account scoped S3 access to the backup bucket via an
# EKS Pod Identity association, so Longhorn backs up without static credentials.
# Longhorn's AWS SDK resolves creds from the ambient chain (the Pod Identity
# agent) when its backup secret carries no AWS_ACCESS_KEY_ID. Enabled by
# consumers (e.g. Nebari Infrastructure Core) that omit static backup keys.
# Follows the same pattern as the AWS Load Balancer Controller association: the
# chart is installed separately, so the association is declared here rather than
# as an EKS-managed addon. The policy is scoped to longhorn_backup_bucket_name,
# whether created above or pre-existing.

module "longhorn_backup_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.7.0"

  count = var.enable_longhorn_backup_pod_identity ? 1 : 0

  name = "${var.project_name}-longhorn-backup"

  attach_custom_policy      = true
  custom_policy_description = "Longhorn off-cluster backup access to S3 bucket ${var.longhorn_backup_bucket_name}"
  policy_statements = [
    {
      sid       = "LonghornBackupBucket"
      actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
      resources = ["arn:${data.aws_partition.current.partition}:s3:::${var.longhorn_backup_bucket_name}"]
    },
    {
      sid = "LonghornBackupObjects"
      actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListMultipartUploadParts",
        "s3:AbortMultipartUpload",
      ]
      resources = ["arn:${data.aws_partition.current.partition}:s3:::${var.longhorn_backup_bucket_name}/*"]
    },
  ]

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "longhorn-system"
      service_account = "longhorn-service-account"
    }
  }

  tags = var.tags
}
