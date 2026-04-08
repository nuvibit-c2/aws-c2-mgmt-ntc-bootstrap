# ---------------------------------------------------------------------------------------------------------------------
# ¦ BACKEND
# ---------------------------------------------------------------------------------------------------------------------
terraform {
  backend "local" {
    # NOTE: This state file is only needed during the bootstrap process and can be deleted afterwards
    path = "bootstrap.tfstate"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ PROVIDER
# ---------------------------------------------------------------------------------------------------------------------
provider "aws" {
  region = var.region
  # NOTE: You can set AWS credentials via environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ REQUIREMENTS
# ---------------------------------------------------------------------------------------------------------------------
terraform {
  required_version = ">= 1.10.6"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 6.0"
      configuration_aliases = []
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ VARIABLES
# ---------------------------------------------------------------------------------------------------------------------
variable "region" {
  description = "AWS region where the state bucket, KMS key, and OIDC provider will be created"
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.region))
    error_message = "Must be a valid AWS region (e.g. eu-central-1, us-east-1)."
  }
}

variable "state_bucket_account_regional_namespace" {
  description = "Use account-regional namespace for the S3 bucket (allows reusing the same bucket name across accounts)"
  type        = bool
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket for storing Terraform/OpenTofu state files"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "Must be a valid S3 bucket name (lowercase, 3-63 characters)."
  }
}

variable "oidc_provider_url" {
  description = "URL of the OIDC identity provider (e.g. https://token.actions.githubusercontent.com for GitHub Actions)"
  type        = string

  validation {
    condition     = can(regex("^https://", var.oidc_provider_url))
    error_message = "Must be a valid HTTPS URL."
  }
}

variable "oidc_client_id_list" {
  description = "List of OIDC client IDs (audiences) allowed to assume the role"
  type        = list(string)
  default     = ["sts.amazonaws.com"]
}

variable "oidc_role_name" {
  description = "Name of the IAM role that the CI/CD pipeline will assume via OIDC"
  type        = string
  default     = "ntc-oidc-github-role"
}

variable "oidc_subjects" {
  description = "List of OIDC subject claims allowed to assume the role (e.g. repo:ORG/REPO:*)"
  type        = list(string)

  validation {
    condition     = length(var.oidc_subjects) > 0
    error_message = "At least one OIDC subject must be specified."
  }
}

variable "oidc_policy_arn" {
  description = "ARN of the IAM policy to attach to the OIDC role"
  type        = string
  default     = "arn:aws:iam::aws:policy/AdministratorAccess"
}

variable "oidc_max_session_duration_hours" {
  description = "Maximum session duration in hours for the OIDC role (1-12)"
  type        = number
  default     = 1

  validation {
    condition     = var.oidc_max_session_duration_hours >= 1 && var.oidc_max_session_duration_hours <= 12
    error_message = "Must be between 1 and 12 hours."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ DATA
# ---------------------------------------------------------------------------------------------------------------------
data "aws_region" "default" {}
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  current_account_id = data.aws_caller_identity.current.account_id
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ NTC BOOTSTRAP
# ---------------------------------------------------------------------------------------------------------------------
module "ntc_bootstrap" {
  source = "./modules/ntc-bootstrap"

  region                                  = var.region
  state_bucket_name                       = var.state_bucket_name
  state_bucket_account_regional_namespace = var.state_bucket_account_regional_namespace

  oidc_configuration = {
    provider_url                  = var.oidc_provider_url
    client_id_list                = var.oidc_client_id_list
    iam_role_name                 = var.oidc_role_name
    subjects                      = var.oidc_subjects
    iam_policy_arn                = var.oidc_policy_arn
    max_session_duration_in_hours = var.oidc_max_session_duration_hours
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------
output "account_id" {
  description = "The AWS account ID where bootstrap was applied"
  value       = local.current_account_id
}