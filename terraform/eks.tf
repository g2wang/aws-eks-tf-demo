module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.13.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.30"

  # Ensure the cluster API endpoint is accessible from the internet
  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    demo_nodes = {
      name         = "eks-demo-node-group"
      min_size     = 1
      max_size     = var.node_count + 1
      desired_size = var.node_count

      instance_types = [var.node_instance_type]
      capacity_type  = "ON_DEMAND"

      # Additional IAM policies for nodes if needed
      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
    }
  }

  # Enable IAM Roles for Service Accounts (IRSA)
  enable_irsa = true

  # Automatically add the current caller identity as an administrator
  enable_cluster_creator_admin_permissions = true

  tags = {
    Environment = "demo"
    Terraform   = "true"
  }
}

# Configure the Kubernetes provider to target the new cluster
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# Configure the Helm provider to target the new cluster
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}
