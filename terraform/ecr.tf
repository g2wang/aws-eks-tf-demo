resource "aws_ecr_repository" "app" {
  name                 = "eks-demo-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  force_delete = true # Allows terraform destroy to clean up repository even if it contains images

  tags = {
    Environment = "demo"
    Terraform   = "true"
  }
}
