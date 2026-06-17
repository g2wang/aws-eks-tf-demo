variable "aws_region" {
  type        = string
  description = "AWS Region to deploy resources"
  default     = "us-east-1"
}

variable "cluster_name" {
  type        = string
  description = "Name of the EKS Cluster"
  default     = "eks-demo-cluster"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "node_instance_type" {
  type        = string
  description = "EC2 Instance type for the EKS node group"
  default     = "t3.medium" # Will run 2 nodes of t3.medium to fit ELK + App
}

variable "node_count" {
  type        = number
  description = "Number of worker nodes in the node group"
  default     = 2
}
