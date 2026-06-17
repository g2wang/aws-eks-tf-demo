#!/usr/bin/env bash
set -euo pipefail

# Get project root directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOT_DIR="$(dirname "$DIR")"

echo "=== Reading Terraform Outputs ==="
cd "$ROOT_DIR/terraform"

if ! ECR_URL=$(terraform output -raw ecr_repository_url 2>/dev/null); then
  echo "Error: Could not retrieve ECR URL. Ensure you have run 'terraform apply' first."
  exit 1
fi

AWS_REGION=$(terraform output -raw aws_region)

echo "ECR URL: $ECR_URL"
echo "AWS Region: $AWS_REGION"

echo "=== Authenticating with AWS ECR ==="
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_URL"

echo "=== Building Docker Image ==="
cd "$ROOT_DIR/app"
docker build --platform linux/amd64 -t "$ECR_URL:latest" .

echo "=== Pushing Docker Image to ECR ==="
docker push "$ECR_URL:latest"

echo "=== Successfully built and pushed $ECR_URL:latest ==="
