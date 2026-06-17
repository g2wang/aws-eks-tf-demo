In Terraform, **there is no single "entry point" file, and files are not executed in alphabetical or sequential order.**

Here is how Terraform decides what to run first:

### 1. Merging All Files
When you run `terraform plan` or `terraform apply` in a directory, Terraform loads **all** files ending with the `.tf` extension in that directory and treats them as a single, combined configuration. 

Splitting resources into separate files like [vpc.tf](file:///Users/guangdewang/github/aws-eks-tf-demo/terraform/vpc.tf), [eks.tf](file:///Users/guangdewang/github/aws-eks-tf-demo/terraform/eks.tf), or [s3.tf](file:///Users/guangdewang/github/aws-eks-tf-demo/terraform/s3.tf) is purely for **human organization and readability**. To Terraform, it is exactly the same as if you wrote the entire configuration in a single, massive `main.tf` file.

### 2. The Dependency Graph (DAG)
Terraform decides the execution order by building a **Directed Acyclic Graph (DAG)** of all the resources defined in your files. It inspects references between resources to determine dependencies:

* **Implicit Dependencies**: If Resource B references a value from Resource A, Terraform automatically knows that Resource A must be created first.
  * *Example:* In [eks.tf](file:///Users/guangdewang/github/aws-eks-tf-demo/terraform/eks.tf), we set `vpc_id = module.vpc.vpc_id`. Because the `eks` module references the output of the `vpc` module, Terraform implicitly decides that the VPC resources in [vpc.tf](file:///Users/guangdewang/github/aws-eks-tf-demo/terraform/vpc.tf) must be built before the EKS cluster.
* **Explicit Dependencies**: If there isn't a direct code reference, but you still need one resource created before another, you can use the `depends_on` meta-argument to force an order.
  * *Example:* In [helm.tf](file:///Users/guangdewang/github/aws-eks-tf-demo/terraform/helm.tf), the Kibana Helm release depends on the Elasticsearch Helm release:
    ```hcl
    depends_on = [helm_release.elasticsearch]
    ```

### Summary of Execution Order for this Project
When you run `terraform apply`, Terraform analyzes the dependencies and automatically executes them in this logical order:
1. **Providers & Variables** are loaded first ([providers.tf](file:///Users/guangdewang/github/aws-eks-tf-demo/terraform/providers.tf), [variables.tf](file:///Users/guangdewang/github/aws-eks-tf-demo/terraform/variables.tf)).
2. **Independent Resources** are created in parallel:
   - VPC network configuration ([vpc.tf](file:///Users/guangdewang/github/aws-eks-tf-demo/terraform/vpc.tf)).
   - ECR container registry ([ecr.tf](file:///Users/guangdewang/github/aws-eks-tf-demo/terraform/ecr.tf)).
   - S3 log bucket ([s3.tf](file:///Users/guangdewang/github/aws-eks-tf-demo/terraform/s3.tf)).
3. **EKS Cluster & Nodes** ([eks.tf](file:///Users/guangdewang/github/aws-eks-tf-demo/terraform/eks.tf)) are created next (since they require the VPC's subnets).
4. **IAM Policies & Roles** ([iam.tf](file:///Users/guangdewang/github/aws-eks-tf-demo/terraform/iam.tf)) are mapped to EKS OIDC.
5. **Helm Releases** ([helm.tf](file:///Users/guangdewang/github/aws-eks-tf-demo/terraform/helm.tf)) are applied last:
   - Fluent Bit installs (needs the EKS cluster and the S3 bucket).
   - Elasticsearch installs (needs the EKS cluster).
   - Kibana installs (waits for Elasticsearch to finish provisioning).
