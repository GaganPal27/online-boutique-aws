###############################################################################
# provider.tf
# Terraform & AWS provider configuration for Online Boutique on AWS EKS
###############################################################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }

  # ---------------------------------------------------------------------------
  # Remote State — recommended for team/portfolio projects.
  # Uncomment and fill in your S3 bucket + DynamoDB table after creating them.
  # ---------------------------------------------------------------------------
  # backend "s3" {
  #   bucket         = "online-boutique-tfstate-<YOUR_ACCOUNT_ID>"
  #   key            = "eks/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "online-boutique-tfstate-lock"
  #   encrypt        = true
  # }
}

###############################################################################
# Primary AWS provider
###############################################################################
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "online-boutique"
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "https://github.com/GaganPal27/online-boutique-aws"
    }
  }
}

###############################################################################
# Kubernetes provider — wired to the EKS cluster created in eks.tf
###############################################################################
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

###############################################################################
# Helm provider — used in Phase 4 for AWS Load Balancer Controller + app chart
###############################################################################
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

###############################################################################
# Input Variables (shared across all files via this single block)
###############################################################################
variable "aws_region" {
  description = "AWS region to deploy all resources."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment label (dev | staging | prod)."
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Short name used as a prefix for all resources."
  type        = string
  default     = "online-boutique"
}
