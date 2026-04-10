# ---------------------------------------------------------------------------------------------------------------------
# ¦ REQUIREMENTS
# ---------------------------------------------------------------------------------------------------------------------
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.37.0"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ DATA
# ---------------------------------------------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
data "tls_certificate" "oidc_provider_cert" {
  url = var.oidc_configuration.provider_url
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  current_account_id = data.aws_caller_identity.current.account_id
  kms_key_arn        = aws_kms_key.ntc_state_bucket_encryption.arn
  oidc_provider      = trimprefix(var.oidc_configuration.provider_url, "https://")
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ KMS ENCRYPTION
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_kms_key" "ntc_state_bucket_encryption" {
  region = var.region

  description             = "encryption key for terraform/opentofu state bucket"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = var.kms_key_rotation_enabled
}

resource "aws_kms_key_policy" "ntc_state_bucket_encryption" {
  region = var.region

  key_id = aws_kms_key.ntc_state_bucket_encryption.key_id
  policy = data.aws_iam_policy_document.ntc_state_bucket_encryption_policy.json
}

data "aws_iam_policy_document" "ntc_state_bucket_encryption_policy" {
  statement {
    sid    = "AllowAdminAccess"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [local.current_account_id]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }
}

resource "aws_kms_alias" "ntc_state_bucket_encryption" {
  region = var.region

  name          = "alias/state-bucket"
  target_key_id = aws_kms_key.ntc_state_bucket_encryption.key_id
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ S3 BUCKET - STATE STORAGE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_s3_bucket" "ntc_tfstate" {
  region = var.region

  bucket           = var.state_bucket_account_regional_namespace ? "${var.state_bucket_name}-${local.current_account_id}-${var.region}-an" : var.state_bucket_name
  bucket_namespace = var.state_bucket_account_regional_namespace ? "account-regional" : "global"
}

resource "aws_s3_bucket_ownership_controls" "ntc_tfstate" {
  region = var.region

  bucket = aws_s3_bucket.ntc_tfstate.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "ntc_tfstate" {
  region = var.region

  bucket = aws_s3_bucket.ntc_tfstate.id
  acl    = "private"

  depends_on = [aws_s3_bucket_ownership_controls.ntc_tfstate]
}

resource "aws_s3_bucket_versioning" "ntc_tfstate" {
  region = var.region

  bucket = aws_s3_bucket.ntc_tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ntc_tfstate" {
  region = var.region

  bucket = aws_s3_bucket.ntc_tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = local.kms_key_arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "ntc_tfstate" {
  region = var.region

  bucket                  = aws_s3_bucket.ntc_tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enhanced S3 bucket policy with granular role-based access controls
data "aws_iam_policy_document" "ntc_tfstate_bucket_policy" {
  # Enforce TLS for all requests
  statement {
    sid    = "EnforceTlsRequestsOnly"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.ntc_tfstate.arn,
      "${aws_s3_bucket.ntc_tfstate.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # Deny TLS versions less than 1.2
  statement {
    sid    = "DenyTLSLessThan1.2"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.ntc_tfstate.arn,
      "${aws_s3_bucket.ntc_tfstate.arn}/*",
    ]

    condition {
      test     = "NumericLessThan"
      variable = "s3:TlsVersion"
      values   = ["1.2"]
    }
  }

  # Allow write access for specific roles with path-based restrictions
  statement {
    sid    = "AllowWriteAccessToOIDCRole"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.ntc_oidc_role.arn]
    }

    actions = [
      "s3:GetObject*",
      "s3:PutObject*",
      "s3:DeleteObject*",
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.ntc_tfstate.arn,
      "${aws_s3_bucket.ntc_tfstate.arn}/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "ntc_tfstate" {
  region = var.region

  bucket = aws_s3_bucket.ntc_tfstate.id
  policy = data.aws_iam_policy_document.ntc_tfstate_bucket_policy.json

  depends_on = [aws_s3_bucket_public_access_block.ntc_tfstate]
}


# ---------------------------------------------------------------------------------------------------------------------
# | IAM - OIDC
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "ntc_oidc_provider" {
  url             = var.oidc_configuration.provider_url
  client_id_list  = var.oidc_configuration.client_id_list
  thumbprint_list = [data.tls_certificate.oidc_provider_cert.certificates[0].sha1_fingerprint]
}

data "aws_iam_policy_document" "ntc_oidc_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.ntc_oidc_provider.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider}:aud"
      values   = var.oidc_configuration.client_id_list
    }
    condition {
      test     = "StringLike"
      variable = "${local.oidc_provider}:sub"
      values   = var.oidc_configuration.subjects
    }
  }
}

resource "aws_iam_role" "ntc_oidc_role" {
  name                 = var.oidc_configuration.iam_role_name
  description          = "OIDC role for CI/CD pipeline access"
  assume_role_policy   = data.aws_iam_policy_document.ntc_oidc_assume_role_policy.json
  max_session_duration = var.oidc_configuration.max_session_duration_in_hours * 3600
}

resource "aws_iam_role_policy_attachment" "ntc_oidc_policy_attachment" {
  role       = aws_iam_role.ntc_oidc_role.id
  policy_arn = var.oidc_configuration.iam_policy_arn
}
