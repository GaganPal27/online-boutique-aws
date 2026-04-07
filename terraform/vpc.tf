###############################################################################
# vpc.tf
# Production-grade VPC: 3 public + 3 private subnets across 3 AZs
# Uses: terraform-aws-modules/vpc/aws (v5.x)
###############################################################################

###############################################################################
# Data sources
###############################################################################

# Dynamically resolve the first 3 AZs in the chosen region.
data "aws_availability_zones" "available" {
  state = "available"
}

###############################################################################
# Local values — single source of truth for CIDR planning
###############################################################################
locals {
  # Pick the first 3 available AZs.
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  # /16 supernet — gives plenty of room for 6 × /20 subnets.
  vpc_cidr = "10.0.0.0/16"

  # Public subnets — host the NAT Gateways, ALB, and bastion (if needed).
  public_subnets = [
    "10.0.0.0/20",   # AZ-a
    "10.0.16.0/20",  # AZ-b
    "10.0.32.0/20",  # AZ-c
  ]

  # Private subnets — EKS worker nodes live here, never directly reachable.
  private_subnets = [
    "10.0.128.0/20", # AZ-a
    "10.0.144.0/20", # AZ-b
    "10.0.160.0/20", # AZ-c
  ]
}

###############################################################################
# VPC Module
###############################################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "${var.project_name}-vpc"
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = local.public_subnets
  private_subnets = local.private_subnets

  # ---------------------------------------------------------------------------
  # NAT Gateways — one per AZ for high availability.
  # Set single_nat_gateway = true to cut costs in dev/staging environments.
  # ---------------------------------------------------------------------------
  enable_nat_gateway     = true
  single_nat_gateway     = false   # true  → ~$130/mo saved; false → HA
  one_nat_gateway_per_az = true

  # ---------------------------------------------------------------------------
  # DNS — required for EKS service discovery and ECR endpoint resolution.
  # ---------------------------------------------------------------------------
  enable_dns_hostnames = true
  enable_dns_support   = true

  # ---------------------------------------------------------------------------
  # Subnet tags — the AWS Load Balancer Controller reads these to auto-discover
  # which subnets to place ALBs (public) and NLBs (private) into.
  # ---------------------------------------------------------------------------
  public_subnet_tags = {
    "kubernetes.io/role/elb"                              = "1"
    "kubernetes.io/cluster/${var.project_name}-eks"       = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                     = "1"
    "kubernetes.io/cluster/${var.project_name}-eks"       = "shared"
  }

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

###############################################################################
# Outputs — consumed by eks.tf and later phases
###############################################################################
output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the three public subnets."
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "IDs of the three private subnets (EKS nodes live here)."
  value       = module.vpc.private_subnets
}

##
