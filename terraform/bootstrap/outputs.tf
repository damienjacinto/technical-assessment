output "state_bucket_name" {
  description = "S3 bucket name to reference from every envs/<environment>/*/backend.tf."
  value       = aws_s3_bucket.state.id
}
