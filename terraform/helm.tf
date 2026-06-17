# Namespace for ELK stack
resource "kubernetes_namespace" "logging" {
  metadata {
    name = "logging"
  }
  depends_on = [module.eks]
}

# Install Elasticsearch
resource "helm_release" "elasticsearch" {
  name       = "elasticsearch"
  repository = "https://helm.elastic.co"
  chart      = "elasticsearch"
  version    = "8.5.1"
  namespace  = kubernetes_namespace.logging.metadata[0].name

  values = [
    <<-EOT
    replicas: 1
    minimumMasterNodes: 1
    clusterName: "elasticsearch-demo"
    
    # Resource constraints for cost savings in development/demo EKS
    resources:
      requests:
        cpu: "100m"
        memory: "512Mi"
      limits:
        cpu: "1000m"
        memory: "1536Mi"
    
    # Configure single-node discovery & disable security for ease of demo setup
    esConfig:
      elasticsearch.yml: |
        xpack.security.enabled: false
        discovery.type: single-node
    EOT
  ]

  depends_on = [module.eks, kubernetes_namespace.logging]
}

# Install Kibana
resource "helm_release" "kibana" {
  name       = "kibana"
  repository = "https://helm.elastic.co"
  chart      = "kibana"
  version    = "8.5.1"
  namespace  = kubernetes_namespace.logging.metadata[0].name

  values = [
    <<-EOT
    elasticsearchHosts: "http://elasticsearch-master:9200"
    
    resources:
      requests:
        cpu: "100m"
        memory: "256Mi"
      limits:
        cpu: "500m"
        memory: "512Mi"
    EOT
  ]

  depends_on = [helm_release.elasticsearch]
}

# Install Fluent Bit
resource "helm_release" "fluent_bit" {
  name       = "fluent-bit"
  repository = "https://fluent.github.io/helm-charts"
  chart      = "fluent-bit"
  version    = "0.47.6"
  namespace  = "kube-system"

  values = [
    <<-EOT
    serviceAccount:
      create: true
      name: "fluent-bit"
      annotations:
        eks.amazonaws.com/role-arn: "${aws_iam_role.fluent_bit_s3.arn}"

    config:
      inputs: |
        [INPUT]
            Name             tail
            Path             /var/log/containers/*.log
            Parser           docker
            Tag              kube.*
            Refresh_Interval 5
            Mem_Buf_Limit    50MB
            Skip_Long_Lines  On

      filters: |
        [FILTER]
            Name                kubernetes
            Match               kube.*
            Kube_URL            https://kubernetes.default.svc:443
            Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
            Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
            Kube_Tag_Prefix     kube.var.log.containers.
            Merge_Log           On
            Keep_Log            Off
            K8S-Logging.Parser  On
            K8S-Logging.Exclude On

      outputs: |
        [OUTPUT]
            Name            s3
            Match           *
            bucket          ${aws_s3_bucket.logs.bucket}
            region          ${var.aws_region}
            store_as        gzip
            use_put_object  true
            upload_chunk_size 5M
            upload_timeout  1m
            s3_key_format   /eks-logs/year=%Y/month=%m/day=%d/hour=%H/%s_$UUID.log.gz

        [OUTPUT]
            Name            http
            Match           *
            Host            logstash-service.logging.svc.cluster.local
            Port            5044
            URI             /
            Format          json
    EOT
  ]

  depends_on = [module.eks, aws_iam_role.fluent_bit_s3, aws_s3_bucket.logs]
}
