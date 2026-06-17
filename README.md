# AWS EKS Kubernetes Demo with Terraform, Spring Boot, S3 Log Shipping & ELK Stack

This repository contains a complete Infrastructure as Code (IaC) demo project that sets up a production-ready networking and Kubernetes environment in AWS EKS. It deploys a Java Spring Boot microservice, streams pod and container logs to an AWS S3 bucket via Fluent Bit, and spins up a full ELK stack (Elasticsearch, Logstash, Kibana) in-cluster for visual log analytics.

---

## Architecture

```
                                +-------------------+
                                |    Client / User  |
                                +---------+---------+
                                          | GET /time
                                          v
                              +-----------+-----------+
                              | AWS Network Load Bal. |
                              +-----------+-----------+
                                          | Port 80
                                          v
                              +-----------+-----------+
                              |   Spring Boot Pod     |
                              | (Writes logs to stdout)|
                              +-----------+-----------+
                                          |
                                          v (log file tailing)
                              +-----------+-----------+
                              | Fluent Bit DaemonSet  |
                              +-----+-----------+-----+
                                    |           |
               (PutObject via IRSA) |           | (HTTP JSON)
                                    v           v
                          +---------+---+   +---+-------------+
                          |  S3 Bucket  |   | Logstash Service|
                          | (Gzip Logs) |   +---+-------------+
                          +-------------+       |
                                                v (Index Logs)
                                            +---+-------------+
                                            |  Elasticsearch  |
                                            +---+-------------+
                                                ^
                                                | (Query)
                                            +---+-------------+
                                            |   Kibana UI     |
                                            +-----------------+
```

---

## Directory Layout

- [app/](./app/): Java Spring Boot microservice code (Java 21, Maven, Dockerfile).
- [terraform/](./terraform/): Terraform configurations for VPC, EKS, ECR, S3, IAM, and Helm charts.
- [k8s/](./k8s/): Kubernetes manifests for Logstash and the Spring Boot application.
- [scripts/](./scripts/): Automated scripts for building, pushing, deploying, and port-forwarding.

---

## Prerequisites

Before starting, ensure you have the following installed locally:
- **Docker Desktop** or Rancher Desktop (must be running to build images)
- **Homebrew** (on macOS)
- **Java 21** & **Maven 3.9+** (if compiling locally, though Docker multi-stage build will also work)

If you do not have the AWS CLI and Terraform installed, run the following commands:
```bash
# Tap and install Terraform
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Install AWS CLI
brew install awscli
```

---

## Deployment Steps

### 1. Configure AWS Credentials
Ensure your local terminal has access to your AWS account. Run:
```bash
aws configure
```
Provide your `AWS Access Key ID`, `AWS Secret Access Key`, default region (e.g., `us-east-1`), and default output format (`json`).

### 2. Provision AWS Infrastructure
Initialize and apply the Terraform configuration. This will provision the VPC, EKS Cluster, ECR Repository, S3 Bucket, and deploy Elasticsearch, Kibana, and Fluent Bit.

```bash
cd terraform
terraform init
terraform apply
```
*Note: EKS cluster and node provisioning typically takes between 10 to 15 minutes.*

### 3. Build and Push the Spring Boot App Image
Execute the build script, which reads the ECR URL from Terraform outputs, compiles the Java application in a Docker image, authenticates with ECR, and pushes the image:

```bash
# From the project root directory:
./scripts/build-and-push.sh
```

### 4. Deploy the Kubernetes workloads (Logstash & Spring Boot App)
Apply the Kubernetes manifests. The deploy script handles configuring your local `kubectl` to target the new EKS cluster, replacing the ECR image placeholder, and deploying the pods:

```bash
./scripts/deploy-app.sh
```

Verify that all pods are starting up:
```bash
kubectl get pods -A
```
Wait until the pods for `time-service`, `logstash`, `elasticsearch-master`, and `kibana` show a `Running` status.

---

## Verification

### 1. Retrieve current time from the microservice
The Spring Boot app is exposed via a Network Load Balancer (NLB). Run:
```bash
kubectl get svc -n default
```
Look for the `EXTERNAL-IP` of the `time-service`. Hit it using `curl`:
```bash
curl http://<EXTERNAL-IP>/time
```
It should return a JSON response containing the epoch milliseconds:
```json
{
  "epoch_ms": 1781708892452,
  "readable_time": "2026-06-17T15:08:12.452Z",
  "service": "time-service",
  "status": "UP"
}
```
*(Alternatively, you can run `./scripts/port-forward.sh`, select option `2` and access it via `http://localhost:8080/time`.)*

### 2. Verify Log Shipping to S3
The Fluent Bit DaemonSet automatically tails container logs and uploads gzip files directly to S3. To list the uploaded logs, fetch your bucket name from Terraform output:
```bash
cd terraform
BUCKET_NAME=$(terraform output -raw s3_logs_bucket)
aws s3 ls "s3://$BUCKET_NAME/eks-logs/" --recursive
```
You should see files stored in `year=YYYY/month=MM/day=DD/hour=HH/` partition folders.

### 3. Visualizing logs in Kibana
Run the port-forward helper script to securely access Kibana:
```bash
./scripts/port-forward.sh
```
Select option `1` for Kibana.
1. Open your browser and navigate to: [http://localhost:5601](http://localhost:5601)
2. Go to **Management** -> **Stack Management** -> **Data Views** (or Index Patterns depending on version).
3. Click **Create data view**.
4. Set the name to `eks-logs-*` (matching the logstash index name).
5. Set the timestamp field to `@timestamp`.
6. Save the data view, then go to **Analytics** -> **Discover** to view, filter, and search your EKS logs live!

---

## Clean Up

To tear down all resources and avoid running up charges in your AWS account, run:
```bash
# Clean up Kubernetes resources first to release Load Balancers
kubectl delete -f k8s/logstash-deployment.yaml
# (Wait for LoadBalancer service deletion to reflect in AWS)

# Destroy Terraform infrastructure
cd terraform
terraform destroy
```
*(The S3 bucket and ECR registry have force-destroy enabled, so Terraform will successfully clean them up even if they contain logs and docker images.)*
