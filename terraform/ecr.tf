###############################################################################
# ecr.tf
# Phase 2 — Amazon ECR repositories for all 11 Online Boutique microservices
###############################################################################

###############################################################################
# Local values
###############################################################################
locals {
  # Canonical list of all 11 microservice names.
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
  enable_key_rotation      = true

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

  name                 = "${var.project_name}/${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

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
# Lifecycle Policies
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
          tagStatus      = "tagged"
          tagPatternList = ["*"]
          countType      = "imageCountMoreThan"
          countNumber = 30
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Remove untagged images after 1 day."
        selection = {
          tagStatus      = "untagged"
          countType      = "sinceImagePushed"
          countUnit      = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
    ]
  })
}

###############################################################################
# Repository Resource Policy
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
# Outputs Removed
# (Moved to outputs.tf to prevent duplication errors)
###############################################################################

# Only keeping non-conflicting output
output "ecr_kms_key_arn" {
  description = "ARN of the KMS key used to encrypt all ECR repositories."
  value       = aws_kms_key.ecr.arn
}
