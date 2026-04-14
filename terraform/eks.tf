###############################################################################
# eks.tf  —  Phase 4
#
# Module : terraform-aws-modules/eks/aws  ~> 20.8
#
# Design decisions vs Phase 1:
#   • Single managed node group (t3.medium, min 2 / max 5) — cost-optimised
#     for a portfolio cluster while still demonstrating autoscaling capability.
#   • enable_cluster_creator_admin_permissions = true — grants system:masters
#     to the IAM identity running terraform apply (your laptop / CI role).
#     No manual aws-auth ConfigMap edits needed.
#   • IRSA roles pre-created for VPC CNI, EBS CSI, and AWS LBC so Phase 4
#     Helm deploys work without any extra IAM work.
#   • Cluster endpoint is public so you can run kubectl from your laptop.
#     Restrict cluster_endpoint_public_access_cidrs to your IP in production.
###############################################################################

###############################################################################
# Resolve the caller's AWS Account ID (used in IAM ARNs below)
###############################################################################
data "aws_caller_identity" "current" {}

###############################################################################
# EKS Cluster
###############################################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.8"

  cluster_name    = "${var.project_name}-eks"
  cluster_version = "1.29"

  # Deploy control plane into private subnets — worker nodes follow suit.
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Public endpoint lets you run kubectl from your laptop without a VPN.
  # In a real production cluster, lock this to your office CIDR.
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]  # ← tighten in prod

  # Encrypt Kubernetes secrets in etcd with a CMK.
  cluster_encryption_config = {
    resources = ["secrets"]
  }

  # ── Managed Add-ons ───────────────────────────────────────────────────────
  # AWS keeps these patched and they integrate cleanly with IRSA.
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent              = true
      before_compute           = true   # must exist before nodes join the cluster
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
      configuration_values = jsonencode({
        env = {
          # Prefix delegation: raises pod density per node from ~29 → ~110
          # on a t3.medium without changing instance type.
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
  }

  # ── Managed Node Group ────────────────────────────────────────────────────
  # Single group: t3.medium (2 vCPU / 4 GB RAM) — sufficient to run all 11
  # Online Boutique microservices concurrently with headroom to spare.
  # Autoscales between 2 (HA baseline) and 5 nodes.
  eks_managed_node_groups = {
    main = {
      name           = "${var.project_name}-ng"
      instance_types = ["t3.medium"]
      ami_type       = "AL2_x86_64"
      capacity_type  = "ON_DEMAND"   # switch to SPOT for further savings

      min_size     = 2   # always 2 for availability (one per AZ)
      max_size     = 5   # HPA / Cluster Autoscaler can burst to 5
      desired_size = 2   # cold-start at minimum

      # gp3 root volume — better IOPS/throughput per dollar than gp2.
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      labels = {
        role = "app"
      }
    }
  }

  # ── IAM Access ────────────────────────────────────────────────────────────
  # Grants system:masters to the identity that runs terraform apply.
  # This replaces the legacy aws-auth ConfigMap approach and works with both
  # IAM users and assumed roles (e.g. your GitHub Actions OIDC role).
  enable_cluster_creator_admin_permissions = true

  tags = {
    Name = "${var.project_name}-eks"
  }
}

###############################################################################
# IRSA — IAM Roles for Service Accounts
# Each pod gets a scoped IAM role injected via a projected token.
# Zero long-lived credentials stored anywhere in the cluster.
###############################################################################

# VPC CNI — manages ENIs and IP prefix delegation on each node.
module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name             = "${var.project_name}-vpc-cni-irsa"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}

# EBS CSI Driver — provisions and attaches EBS volumes for PersistentVolumeClaims.
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name             = "${var.project_name}-ebs-csi-irsa"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

# AWS Load Balancer Controller — provisions ALBs/NLBs for Kubernetes Ingress
# and Service objects. Required for Phase 4 Helm deployment.
module "aws_lb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name                              = "${var.project_name}-aws-lbc-irsa"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}
