#!/usr/bin/env bash
set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOT_DIR="$(dirname "$DIR")"

echo "=== Configuring Kubeconfig ==="
cd "$ROOT_DIR/terraform"

if ! CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null); then
  echo "Error: Could not retrieve EKS cluster name. Ensure you have run 'terraform apply' first."
  exit 1
fi

AWS_REGION=$(terraform output -raw aws_region)
ECR_URL=$(terraform output -raw ecr_repository_url)

echo "Cluster Name: $CLUSTER_NAME"
echo "Updating kubeconfig..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

echo "=== Deploying Logstash ==="
kubectl apply -f "$ROOT_DIR/k8s/logstash-deployment.yaml"

echo "=== Preparing App Deployment Manifest ==="
MANIFEST_TEMP=$(mktemp)
sed "s|IMAGE_PLACEHOLDER|$ECR_URL:latest|g" "$ROOT_DIR/k8s/app-deployment.yaml" > "$MANIFEST_TEMP"

echo "=== Deploying Spring Boot Application ==="
kubectl apply -f "$MANIFEST_TEMP"
rm "$MANIFEST_TEMP"

echo "=== Deployment Commands Sent ==="
echo "You can check status using:"
echo "  kubectl get pods -A"
echo "  kubectl get svc -n default"
