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
