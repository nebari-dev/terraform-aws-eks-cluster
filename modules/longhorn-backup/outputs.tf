output "bucket_id" {
  description = "Name of the Longhorn backup S3 bucket (null if not created)"
  value       = one(aws_s3_bucket.this[*].id)
}

output "pod_identity_role_arn" {
  description = "IAM role ARN for the Longhorn backup pod identity association (null if enable_pod_identity is false)"
  value       = one(module.pod_identity[*].iam_role_arn)
}
