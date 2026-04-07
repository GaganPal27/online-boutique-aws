###############################################################################
# ecr.tf
# Phase 2 — Amazon ECR repositories for all 11 Online Boutique microservices
#
# Design decisions:
#   • for_each over a set of strings  → one resource block manages all 11 repos
#   • scan_on_push = true             → free Basic scanning on every docker push
#   • image_tag_mutability = MUTABLE  → allows the CI pipeline to reuse tags
#     like "latest" and branch names (flip to IMMUTABLE once you adopt
#     a strict semver/SHA-only tagging policy in prod)
#   • Lifecycle policy                → keeps the last 30 tagged images and
#     purges untagged layers after 1 day (prevents runaway storage costs)
#   • KMS encryption                 → encrypts images at rest with a
#     customer-managed key (CMK) for compliance / portfolio credibility
#   • Repository policy              → locks access to the owning AWS account
#     only; GitHub Actions will assume an IAM role in that account (Phase 3)
###############################################################################

###############################################################################
# Local values
###############################################################################
locals {
  # Canonical list of all 11 microservice names.
  # This is the single source of truth — referenced by for_each, policies,
  # and outputs so nothing goes out of sync.
  microservices = toset([
    "frontend",
    "cartservice",
    "productcatalogservice",
    "currencyservice",
    "paymentservice",
    "shippingservice",
    "emailservice",
    "checkoutservice",
    "recommendationservice",
    "adservice",
    "loadgenerator",
  ])
}

###############################################################################
# KMS key — encrypts every repository's images at rest
###############################################################################
resource "aws_kms_key" "ecr" {
  description             = "${var.project_name} ECR encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-ecr-kms-key"
  }
}

resource "aws_kms_alias" "ecr" {
  name          = "alias/${var.project_name}-ecr"
  target_key_id = aws_kms_key.ecr.key_id
}

###############################################################################
# ECR Repositories — one per microservice via for_each
###############################################################################
resource "aws_ecr_repository" "microservices" {
  for_each = local.microservices

  # Naming convention: <project>/<service>
  # e.g. online-boutique/frontend
  name                 = "${var.project_name}/${each.key}"
  image_tag_mutability = "MUTABLE"

  # Basic scanning — free, fires on every push, catches known CVEs.
  # Upgrade to ENHANCED for continuous/runtime scanning (costs extra).
  image_scanning_configuration {
    scan_on_push = true
  }

  # AES-256 via CMK — stronger than the default AWS-managed key.
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr.arn
  }

  # Prevent accidental terraform destroy from deleting images.
  force_delete = false

  tags = {
    Name      = "${var.project_name}/${each.key}"
    Service   = each.key
  }
}

###############################################################################
# Lifecycle Policies — applied to every repository
# Rules (evaluated in priority order):
#   1. Keep the last 30 tagged images  (branch builds, release candidates)
#   2. Expire untagged images after 1 day  (dangling build layers)
###############################################################################
resource "aws_ecr_lifecycle_policy" "microservices" {
  for_each   = local.microservices
  repository = aws_ecr_repository.microservices[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep the last 30 tagged images per repository."
        selection = {
          tagStatus   = "tagged"
          tagPatternList = ["*"]
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Remove untagged images after 1 day."
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
    ]
  })
}

###############################################################################
# Repository Resource Policy
# Restricts pull/push access to the owning AWS account only.
# GitHub Actions (Phase 3) will authenticate via OIDC into an IAM role
# inside this account — so cross-account access is not needed here.
###############################################################################
resource "aws_ecr_repository_policy" "microservices" {
  for_each   = local.microservices
  repository = aws_ecr_repository.microservices[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAccountAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:GetRepositoryPolicy",
          "ecr:ListImages",
          "ecr:DeleteRepository",
          "ecr:BatchDeleteImage",
          "ecr:SetRepositoryPolicy",
          "ecr:DeleteRepositoryPolicy",
        ]
      },
    ]
  })
}

###############################################################################
# Outputs
###############################################################################

# Full map of service → repository URL.
# Use this in GitHub Actions:
#   IMAGE_URI: ${{ steps.tf-outputs.outputs.ecr_repository_urls['frontend'] }}
output "ecr_repository_urls" {
  description = "Map of microservice name → ECR repository URL (use in CI/CD)."
  value       = { for k, repo in aws_ecr_repository.microservices : k => repo.repository_url }
}

# Registry base URL (account + region stem, no repo path).
# Needed for `docker login` in GitHub Actions:
#   aws ecr get-login-password | docker login --username AWS --password-stdin <registry>
output "ecr_registry_url" {
  description = "ECR registry base URL for docker login (account.dkr.ecr.region.amazonaws.com)."
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

# KMS key ARN — record for auditing and key-policy updates.
output "ecr_kms_key_arn" {
  description = "ARN of the KMS key used to encrypt all ECR repositories."
  value       = aws_kms_key.ecr.arn
}
