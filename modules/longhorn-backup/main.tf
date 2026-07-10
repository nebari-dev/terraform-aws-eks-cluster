data "aws_partition" "current" {}

################################################################################
# Longhorn backup bucket (optional)
################################################################################
# Optional S3 bucket for Longhorn off-cluster backups. Disabled by default;
# enabled by consumers (e.g. Nebari Infrastructure Core) that schedule Longhorn
# snapshots/backups to S3. When force_destroy is false (the default),
# `terraform destroy` refuses to delete a non-empty bucket, protecting existing
# backups.

resource "aws_s3_bucket" "this" {
  count         = var.create_bucket ? 1 : 0
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
  tags          = var.tags
}

resource "aws_s3_bucket_versioning" "this" {
  count  = var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.this[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

# Longhorn prunes expired backups with plain DeleteObject calls, which on a
# versioned bucket only write a delete marker and demote the object to a
# noncurrent version that S3 retains (and bills) indefinitely. This rule
# garbage-collects what versioning holds back: noncurrent versions are kept
# for noncurrent_version_expiration_days as a recovery window for accidentally
# deleted backups, orphaned delete markers are removed, and incomplete
# multipart uploads from crashed backup pods are aborted.
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.this[0].id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }

    expiration {
      expired_object_delete_marker = true
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  count  = var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.this[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  count  = var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.this[0].id

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
# as an EKS-managed addon. The policy is scoped to bucket_name, whether created
# above or pre-existing.

module "pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.7.0"

  count = var.enable_pod_identity ? 1 : 0

  name = "${var.project_name}-longhorn-backup"

  attach_custom_policy      = true
  custom_policy_description = "Longhorn off-cluster backup access to S3 bucket ${var.bucket_name}"
  policy_statements = [
    {
      sid       = "LonghornBackupBucket"
      actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
      resources = ["arn:${data.aws_partition.current.partition}:s3:::${var.bucket_name}"]
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
      resources = ["arn:${data.aws_partition.current.partition}:s3:::${var.bucket_name}/*"]
    },
  ]

  associations = {
    this = {
      cluster_name    = var.cluster_name
      namespace       = "longhorn-system"
      service_account = "longhorn-service-account"
    }
  }

  tags = var.tags
}
