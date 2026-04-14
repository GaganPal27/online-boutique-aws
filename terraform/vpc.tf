###############################################################################
# vpc.tf  —  Phase 4
#
# Module  : terraform-aws-modules/vpc/aws  ~> 5.8
# Topology: 3 public + 3 private subnets across 3 AZs
#   Public  subnets → NAT Gateways, internet-facing ALB
#   Private subnets → EKS worker nodes (zero direct internet exposure)
###############################################################################

###############################################################################
# Resolve the first 3 available AZs at plan time
###############################################################################
data "aws_availability_zones" "available" {
  state = "available"
}

###############################################################################
# Locals — single source of truth for all CIDR values
###############################################################################
locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  # /16 supernet → 65k IPs total
  # Each /20 subnet → 4,091 usable IPs (plenty for 11 services + autoscaling)
  vpc_cidr        = "10.0.0.0/16"
  public_subnets  = ["10.0.0.0/20",   "10.0.16.0/20",  "10.0.32.0/20"]
  private_subnets = ["10.0.128.0/20", "10.0.144.0/20", "10.0.160.0/20"]
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

  # ── NAT Gateways ──────────────────────────────────────────────────────────
  # one_nat_gateway_per_az = true → survives a single AZ failure (HA).
  # Flip single_nat_gateway = true to save ~$100/mo for dev/portfolio use.
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  # ── DNS ───────────────────────────────────────────────────────────────────
  # Required for EKS CoreDNS, ECR endpoint resolution, and service discovery.
  enable_dns_hostnames = true
  enable_dns_support   = true

  # ── Subnet tags ───────────────────────────────────────────────────────────
  # AWS Load Balancer Controller reads these to auto-discover target subnets.
  # Missing tags = LBC silently fails to provision ALBs → services unreachable.
  public_subnet_tags = {
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${var.project_name}-eks" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/${var.project_name}-eks" = "shared"
  }

  tags = {
    Name = "${var.project_name}-vpc"
  }
}
