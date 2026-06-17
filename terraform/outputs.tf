output "aws_region" {
  value       = var.aws_region
  description = "AWS Region deployed to"
}

output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID"
}

output "cluster_name" {
  value       = module.eks.cluster_name
  description = "EKS Cluster Name"
}

output "cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "EKS Cluster Control Plane API Endpoint"
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.app.repository_url
  description = "URL of the ECR Repository for the Spring Boot application"
}

output "s3_logs_bucket" {
  value       = aws_s3_bucket.logs.bucket
  description = "S3 Bucket storing raw EKS logs"
}

output "configure_kubectl" {
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
  description = "Command to configure kubectl locally"
}
