In Terraform, **there is no single "entry point" file, and files are not executed in alphabetical or sequential order.**

Here is how Terraform decides what to run first:

### 1. Merging All Files
When you run `terraform plan` or `terraform apply` in a directory, Terraform loads **all** files ending with the `.tf` extension in that directory and treats them as a single, combined configuration. 

Splitting resources into separate files like [vpc.tf](./vpc.tf), [eks.tf](./eks.tf), or [s3.tf](./s3.tf) is purely for **human organization and readability**. To Terraform, it is exactly the same as if you wrote the entire configuration in a single, massive `main.tf` file.

### 2. The Dependency Graph (DAG)
Terraform decides the execution order by building a **Directed Acyclic Graph (DAG)** of all the resources defined in your files. It inspects references between resources to determine dependencies:

* **Implicit Dependencies**: If Resource B references a value from Resource A, Terraform automatically knows that Resource A must be created first.
  * *Example:* In [eks.tf](./eks.tf), we set `vpc_id = module.vpc.vpc_id`. Because the `eks` module references the output of the `vpc` module, Terraform implicitly decides that the VPC resources in [vpc.tf](./vpc.tf) must be built before the EKS cluster.
* **Explicit Dependencies**: If there isn't a direct code reference, but you still need one resource created before another, you can use the `depends_on` meta-argument to force an order.
  * *Example:* In [helm.tf](./helm.tf), the Kibana Helm release depends on the Elasticsearch Helm release:
    ```hcl
    depends_on = [helm_release.elasticsearch]
    ```

### Summary of Execution Order for this Project
When you run `terraform apply`, Terraform analyzes the dependencies and automatically executes them in this logical order:
1. **Providers & Variables** are loaded first ([providers.tf](./providers.tf), [variables.tf](./variables.tf)).
2. **Independent Resources** are created in parallel:
   - VPC network configuration ([vpc.tf](./vpc.tf)).
   - ECR container registry ([ecr.tf](./ecr.tf)).
   - S3 log bucket ([s3.tf](./s3.tf)).
3. **EKS Cluster & Nodes** ([eks.tf](./eks.tf)) are created next (since they require the VPC's subnets).
4. **IAM Policies & Roles** ([iam.tf](./iam.tf)) are mapped to EKS OIDC.
5. **Helm Releases** ([helm.tf](./helm.tf)) are applied last:
   - Fluent Bit installs (needs the EKS cluster and the S3 bucket).
   - Elasticsearch installs (needs the EKS cluster).
   - Kibana installs (waits for Elasticsearch to finish provisioning).

---

## On `resource` and `data`

In Terraform, the two most fundamental blocks used to construct configurations are **Resources** and **Data Sources**.

Here is the difference between them, using examples from the project we just set up:

---

## 1. Resources (`resource`) — "The Creators"

A `resource` block defines infrastructure components that Terraform will **create, manage, update, and destroy**.

* **State Tracking**: Terraform manages the lifecycle of resources. It writes details about them to a local or remote state file (`terraform.tfstate`) and modifies or deletes them in AWS when you change your code.
* **Write Action**: Running `terraform apply` on a resource block results in API requests that provision physical or virtual assets.

### Example from our project:
In [s3.tf](./s3.tf), we created a new S3 bucket to hold logs:
```hcl
resource "aws_s3_bucket" "logs" {
  bucket        = "eks-pod-logs-${random_string.suffix.result}"
  force_destroy = true
}
```
* **What it does**: When you run `terraform apply`, Terraform talks to the AWS API, provisions a brand-new S3 bucket, and records its details in the state file so it can delete it later during `terraform destroy`.

---

## 2. Data Sources (`data`) — "The Queries"

A `data` block (often called a Data Source) is **read-only**. It is used to **fetch, query, or compute information** from APIs or existing infrastructure *outside* of the current Terraform scope.

* **No Lifecycle Management**: Data sources do not create or delete infrastructure. They simply pull existing information so other resources can use it.
* **Read Action**: Running `terraform apply` on a data source just retrieves data (e.g., finding the ID of a pre-existing VPC, getting the latest Ubuntu AMI, or generating a policy document).

### Example 1: Querying AWS APIs
In [iam.tf](./iam.tf), we used a data block to dynamically generate a formatted JSON policy structure for the IAM role:
```hcl
data "aws_iam_policy_document" "fluent_bit_s3_policy" {
  statement {
    effect  = "Allow"
    actions = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
    resources = [
      aws_s3_bucket.logs.arn,
      "${aws_s3_bucket.logs.arn}/*"
    ]
  }
}
```
* **What it does**: It doesn't create any IAM resource in AWS. It just computes a JSON string locally within Terraform's memory. Later, we assign this computed JSON to an actual policy resource:
  ```hcl
  resource "aws_iam_policy" "fluent_bit_s3" {
    policy = data.aws_iam_policy_document.fluent_bit_s3_policy.json
  }
  ```

### Example 2: Accessing Existing Infrastructure
If you wanted to deploy EKS to a VPC that someone else had already created in your AWS account, instead of writing a `resource "aws_vpc"` block, you would write:
```hcl
data "aws_vpc" "existing_vpc" {
  tags = {
    Name = "production-vpc"
  }
}
```
* **What it does**: Terraform queries AWS to locate a VPC named `production-vpc`, gets its CIDR block, subnets, and ID, and allows you to reference it in your EKS code (e.g., `data.aws_vpc.existing_vpc.id`) without attempting to manage or delete it.

---

## Summary Comparison

| Feature | Resource (`resource`) | Data Source (`data`) |
| :--- | :--- | :--- |
| **Purpose** | Create and manage infrastructure | Query information / existing state |
| **AWS API Action** | POST, PUT, DELETE (Write/Modify) | GET (Read-only) |
| **Terraform State** | Tracked and managed in state file | Evaluated during run (not managed) |
| **Destruction** | Deleted during `terraform destroy` | Untouched during `terraform destroy` |

---

## On file suffixes

The file suffix in a Terraform directory **matters configurationally**. Terraform relies on specific extensions to understand the purpose of each file:

---

## 1. The `.tf` Suffix (Configuration Files)
Files ending in `.tf` contain your **infrastructure code** (resources, data sources, providers, outputs, and variable declarations).

* **Automatic Loading**: Whenever you run a command like `terraform plan` or `terraform apply`, Terraform automatically reads **every** `.tf` file in the current directory and merges them.
* **Syntax**: These files use HashiCorp Configuration Language (HCL) syntax (e.g., `resource "aws_s3_bucket" "name" {}`).

---

## 2. The `.tfvars` Suffix (Variable Ingestion Files)
Files ending in `.tfvars` contain **variable values** (data assignments), not infrastructure code. They are used to set values for variables you declared in your `.tf` files.

* **Syntax**: These files are written as key-value pairs:
  ```hcl
  # production.tfvars
  aws_region         = "us-west-2"
  node_instance_type = "t3.large"
  node_count         = 5
  ```
* **How Terraform Loads Them**:
  * **Automatically Loaded**: Files named exactly `terraform.tfvars` or ending in `*.auto.tfvars` (e.g., `vpc.auto.tfvars`) are loaded automatically.
  * **Manually Loaded**: Files with any other name (like `production.tfvars` or `staging.tfvars`) must be passed manually in the CLI using the `-var-file` flag:
    ```bash
    terraform apply -var-file="production.tfvars"
    ```

---

## Other Common Suffixes in Terraform

* **`.tfstate` / `.tfstate.backup`**: JSON files created by Terraform to track the current state of your deployed resources. **Never edit these files manually.**
* **`.hcl`**: Generic HCL extension. The most common is `.terraform.lock.hcl`, which is generated automatically during `terraform init` to lock provider versions.
* **`.tf.json` and `.tfvars.json`**: Alternatives to `.tf` and `.tfvars` that allow you to write your configuration or variables in standard JSON syntax if you are generating configurations programmatically.

---

## Summary of Differences

| Suffix | Purpose | Auto-loaded? | Contains |
| :--- | :--- | :--- | :--- |
| **`.tf`** | Declares infrastructure & variables | Yes | Resources, Modules, Data, Variables, Outputs |
| **`.tfvars`** | Assigns values to declared variables | Only `terraform.tfvars` & `*.auto.tfvars` | `variable_name = "value"` |
