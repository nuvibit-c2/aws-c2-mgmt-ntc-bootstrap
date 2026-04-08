# NTC Implementation Blueprint - Bootstrap

This repository is part of the **Nuvibit Terraform Collection (NTC) Implementation Blueprints** - a comprehensive reference implementation showcasing best practices for building enterprise-grade AWS platforms using NTC building blocks.


## 🎯 Overview

The NTC Implementation Blueprints provide a complete, production-ready example of how to structure and deploy AWS infrastructure using the [Nuvibit Terraform Collection](https://docs.nuvibit.com/ntc-library/). These blueprints are deployed in a dedicated customer-simulated AWS organization (`aws-c2-*`), demonstrating real-world multi-account architecture patterns and configurations.

### Key Characteristics

- **Best Practice Architecture**: Implements the [Nuvibit AWS Reference Architecture (NARA)](https://docs.nuvibit.com/whitepapers/nuvibit-aws-reference-architecture/) with battle-tested patterns
- **GitOps Workflow**: All infrastructure is managed through Git with automated CI/CD pipelines
- **Secure Authentication**: Uses OpenID Connect (OIDC) for secure, short-lived credentials
- **Modular Design**: Each repository manages a specific domain or AWS account
- **Production-Ready**: Demonstrates configurations suitable for enterprise deployments

## 📋 Purpose of This Repository

This repository (`aws-c2-mgmt-bootstrap`) is the **one-time initial setup step** for a new NTC implementation. It is executed locally against the AWS Management Account to provision the foundational resources required by all subsequent NTC blueprint repositories:

- **State Storage**: Creates a secure, encrypted S3 bucket for storing Terraform/OpenTofu state files
- **KMS Encryption**: Creates a KMS key for state file encryption at rest
- **CI/CD Authentication**: Sets up an OIDC provider and IAM role so CI/CD pipelines can securely authenticate to AWS without static credentials

> **Note**: This bootstrap is designed to be run once. The local state file (`bootstrap.tfstate`) can be safely discarded after a successful apply. All created resources will be imported at a later stage and do not depend on this state file for ongoing operation.


## 🚀 Quick Start

### Prerequisites

1. **AWS CLI** configured with credentials for the **Management Account** (admin-level permissions)
2. **OpenTofu** (>= 1.10.6) or **Terraform** (>= 1.10.6) installed locally
3. A **CI/CD platform** with OIDC support (GitHub Actions, GitLab CI/CD, Spacelift, etc.)

### Step 1: Clone and Configure

```bash
git clone https://github.com/nuvibit-c2/aws-c2-mgmt-bootstrap.git
cd aws-c2-mgmt-bootstrap
```

Edit `bootstrap.auto.tfvars` with your configuration:

```hcl
# AWS region for state bucket, KMS key, and OIDC provider
region = "eu-central-1"

# S3 bucket name for Terraform/OpenTofu state
state_bucket_name = "tfstate"

# OIDC provider URL for your CI/CD platform
oidc_provider_url = "https://token.actions.githubusercontent.com"

# IAM role name for CI/CD pipeline
oidc_role_name = "ntc-oidc-github-role"

# OIDC subject claims (controls which repos/pipelines can authenticate)
oidc_subjects = [
  "repo:MY_ORG/MY_REPO:*",
]
```

### Step 2: Run Bootstrap

```bash
tofu init
tofu plan
tofu apply
```

### Step 3: Done

After a successful apply, note the outputs (account ID, region). The local state file (`bootstrap.tfstate`) is no longer needed and can be deleted.

You are now ready to proceed with deploying the NTC blueprint repositories in order.


## ⚙️ Configuration Reference

| Variable | Description | Default |
|---|---|---|
| `region` | AWS region for bootstrap resources | *(required)* |
| `state_bucket_name` | S3 bucket name for state storage | *(required)* |
| `state_bucket_account_regional_namespace` | Use account-regional S3 namespace | *(required)* |
| `oidc_provider_url` | OIDC provider URL | *(required)* |
| `oidc_client_id_list` | OIDC audience / client IDs | `["sts.amazonaws.com"]` |
| `oidc_role_name` | IAM role name for CI/CD | `"ntc-oidc-github-role"` |
| `oidc_subjects` | Allowed OIDC subject claims | *(required)* |
| `oidc_policy_arn` | IAM policy ARN for the OIDC role | `"arn:aws:iam::aws:policy/AdministratorAccess"` |
| `oidc_max_session_duration_hours` | Max session duration (1-12 hours) | `1` |

### OIDC Subject Examples

**GitHub Actions:**
```hcl
oidc_provider_url = "https://token.actions.githubusercontent.com"
oidc_subjects     = ["repo:my-org/my-repo:*"]
```

**GitLab CI/CD:**
```hcl
oidc_provider_url = "https://gitlab.com"
oidc_subjects     = ["project_path:my-group/my-project:ref_type:branch:ref:main"]
```

**Spacelift:**
```hcl
oidc_provider_url = "https://my-account.app.spacelift.io"
oidc_subjects     = ["spacelift:my-account:space:root:*"]
```


## 🏗️ Complete Blueprint Architecture

The NTC Implementation Blueprints consist of multiple repositories, each managing a specific domain or AWS account:

### Bootstrap

#### 0. [aws-c2-mgmt-bootstrap](https://github.com/nuvibit-c2/aws-c2-mgmt-bootstrap) ← *You are here*
**Purpose**: One-time initial setup for a new NTC implementation
**Creates**: S3 state bucket, KMS encryption key, OIDC provider and IAM role for CI/CD

### Core Management Repositories

#### 1. [aws-c2-mgmt-organizations](https://github.com/nuvibit-c2/aws-c2-mgmt-organizations)
**Purpose**: Foundation of the AWS organization
**Manages**: AWS Organizations, OU structure, SCPs, service integrations, cross-account parameters
**Building Blocks**: [NTC Organizations](https://docs.nuvibit.com/ntc-building-blocks/management/ntc-organizations/), [NTC Guardrail Templates](https://docs.nuvibit.com/ntc-building-blocks/templates/ntc-guardrail-templates/), [NTC Parameters](https://docs.nuvibit.com/ntc-building-blocks/management/ntc-parameters/)

#### 2. [aws-c2-mgmt-account-factory](https://github.com/nuvibit-c2/aws-c2-mgmt-account-factory)
**Purpose**: Automated AWS account provisioning and lifecycle management
**Manages**: Account creation, baseline configuration, budget alerts, lifecycle automation
**Building Blocks**: [NTC Account Factory](https://docs.nuvibit.com/ntc-building-blocks/management/ntc-account-factory/), [NTC Parameters](https://docs.nuvibit.com/ntc-building-blocks/management/ntc-parameters/)

#### 3. [aws-c2-mgmt-identity-center](https://github.com/nuvibit-c2/aws-c2-mgmt-identity-center)
**Purpose**: Centralized identity and access management
**Manages**: AWS IAM Identity Center (SSO), permission sets, user/group assignments
**Building Blocks**: [NTC Identity Center](https://docs.nuvibit.com/ntc-building-blocks/management/ntc-identity-center/), [NTC Parameters](https://docs.nuvibit.com/ntc-building-blocks/management/ntc-parameters/)

### Core Account Repositories

#### 4. [aws-c2-log-archive](https://github.com/nuvibit-c2/aws-c2-log-archive)
**Purpose**: Centralized logging and audit trail storage
**Manages**: S3 buckets for CloudTrail, VPC Flow Logs, security findings
**Building Blocks**: [NTC Log Archive](https://docs.nuvibit.com/ntc-building-blocks/security/ntc-log-archive/), [NTC Parameters](https://docs.nuvibit.com/ntc-building-blocks/management/ntc-parameters/)

#### 5. [aws-c2-security](https://github.com/nuvibit-c2/aws-c2-security)
**Purpose**: Centralized security monitoring and compliance
**Manages**: Security Hub, GuardDuty, Inspector, Config, IAM Access Analyzer
**Building Blocks**: [NTC Security Tooling](https://docs.nuvibit.com/ntc-building-blocks/security/ntc-security-tooling/), [NTC Parameters](https://docs.nuvibit.com/ntc-building-blocks/management/ntc-parameters/)

#### 6. [aws-c2-connectivity](https://github.com/nuvibit-c2/aws-c2-connectivity)
**Purpose**: Network infrastructure and connectivity
**Manages**: Transit Gateway, VPCs, Route 53, IPAM, network architecture
**Building Blocks**: [NTC Core Network](https://docs.nuvibit.com/ntc-building-blocks/connectivity/ntc-core-network/), [NTC VPC](https://docs.nuvibit.com/ntc-building-blocks/connectivity/ntc-vpc/), [NTC IPAM](https://docs.nuvibit.com/ntc-building-blocks/connectivity/ntc-ipam/), [NTC Route53](https://docs.nuvibit.com/ntc-building-blocks/connectivity/ntc-route53/), [NTC Parameters](https://docs.nuvibit.com/ntc-building-blocks/management/ntc-parameters/)


## 📚 Deployment Order

The blueprint repositories should be deployed in the following order:

0. **aws-c2-mgmt-bootstrap** ← *You are here* (one-time local apply)
1. **aws-c2-mgmt-organizations** (creates organization structure)
2. **aws-c2-mgmt-account-factory** (creates core accounts)
3. **aws-c2-mgmt-identity-center** (creates SSO permissions)
4. **aws-c2-log-archive** (creates audit log archive)
5. **aws-c2-security** (creates security tooling)
6. **aws-c2-connectivity** (creates central connectivity)

For detailed deployment instructions, refer to the [NTC Quickstart Guide](https://docs.nuvibit.com/getting-started/quickstart/).


## 🔗 Additional Resources

- **[NTC Documentation](https://docs.nuvibit.com/)** - Complete documentation for all NTC building blocks
- **[NTC Library](https://docs.nuvibit.com/ntc-library/)** - Browse all available NTC modules
- **[Nuvibit AWS Reference Architecture](https://docs.nuvibit.com/whitepapers/nuvibit-aws-reference-architecture/)** - Architecture whitepaper
- **[CI/CD Pipelines for IaC](https://docs.nuvibit.com/whitepapers/cicd-pipelines-iac-delivery/)** - CI/CD best practices
- **[Nuvibit Website](https://nuvibit.com/)** - Company information and contact


## 🤝 Support

For questions, issues, or consultation regarding NTC implementation:

- **Documentation**: [docs.nuvibit.com](https://docs.nuvibit.com/)
- **Contact**: [nuvibit.com/contact](https://nuvibit.com/contact/)
- **Email**: info@nuvibit.com


## 📄 License

This repository demonstrates the usage of the Nuvibit Terraform Collection. Please refer to your NTC subscription agreement for licensing terms.

---

**Built with ❤️ by [Nuvibit](https://nuvibit.com/)**