data "aws_iam_policy_document" "fluent_bit_s3_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:kube-system:fluent-bit"]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [module.eks.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "fluent_bit_s3" {
  name               = "${var.cluster_name}-fluent-bit-s3"
  assume_role_policy = data.aws_iam_policy_document.fluent_bit_s3_assume_role.json

  tags = {
    Environment = "demo"
    Terraform   = "true"
  }
}

data "aws_iam_policy_document" "fluent_bit_s3_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.logs.arn,
      "${aws_s3_bucket.logs.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "fluent_bit_s3" {
  name        = "${var.cluster_name}-fluent-bit-s3-policy"
  description = "IAM policy for Fluent Bit to upload logs to S3"
  policy      = data.aws_iam_policy_document.fluent_bit_s3_policy.json
}

resource "aws_iam_role_policy_attachment" "fluent_bit_s3" {
  role       = aws_iam_role.fluent_bit_s3.name
  policy_arn = aws_iam_policy.fluent_bit_s3.arn
}
