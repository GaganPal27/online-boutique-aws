###############################################################################
# eks.tf
# Production-grade EKS cluster with Managed Node Groups
# Uses: terraform-aws-modules/eks/aws (v20.x)
###############################################################################

###############################################################################
# Data sources
###############################################################################

# Resolve the caller's AWS account ID — used in IAM ARNs.
data "aws_caller_identity" "current" {}

###############################################################################
# EKS Module
###############################################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.8"

  cluster_name    = "${var.project_name}-eks"
  cluster_version = "1.29"

  # Deploy the EKS control plane into the private subnets.
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Make the API server publicly reachable so you can run kubectl from your
  # laptop.  Lock this down to your office/home CIDR in production.
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"] # ← tighten in prod

  # Encrypt etcd secrets with a CMK.
  cluster_encryption_config = {
    resources = ["secrets"]
  }

  # ---------------------------------------------------------------------------
  # Core add-ons — managed and kept up to date by AWS.
  # ---------------------------------------------------------------------------
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent              = true
      before_compute           = true          # must exist before nodes join
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
      configuration_values = jsonencode({
        env = {
          # Enable prefix delegation for higher pod density.
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

  # ---------------------------------------------------------------------------
  # Managed Node Groups
  # Two groups:
  #   • system  — small, on-demand nodes for cluster add-ons & controllers
  #   • app     — larger, mixed on-demand + Spot nodes for the microservices
  # ---------------------------------------------------------------------------
  eks_managed_node_groups = {

    # ------------------------------------------------------------------
    # System node group  (always on-demand, tainted so only system pods
    # land here)
    # ------------------------------------------------------------------
    system = {
      name            = "system"
      instance_types  = ["t3.medium"]
      ami_type        = "AL2_x86_64"
      capacity_type   = "ON_DEMAND"

      min_size     = 1
      max_size     = 3
      desired_size = 2

      taints = [
        {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]

      labels = {
        role = "system"
      }

      # EBS root volume — 50 GB gp3 for system nodes.
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
    }

    # ------------------------------------------------------------------
    # Application node group  (Spot + on-demand mix; hosts all 11 services)
    # ------------------------------------------------------------------
    app = {
      name = "app"
      # Multiple instance families → Spot diversification.
      instance_types = ["m5.large", "m5a.large", "m5d.large", "m6i.large"]
      ami_type       = "AL2_x86_64"
      capacity_type  = "SPOT"

      min_size     = 2
      max_size     = 10
      desired_size = 3

      labels = {
        role = "app"
      }

      # EBS root volume — 100 GB gp3 for app nodes.
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 100
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }
    }
  }

  # ---------------------------------------------------------------------------
  # Grant the caller (you / CI) admin access on the cluster via the EKS access
  # API (replaces the legacy aws-auth ConfigMap).
  # ---------------------------------------------------------------------------
  enable_cluster_creator_admin_permissions = true

  tags = {
    Name = "${var.project_name}-eks"
  }
}

###############################################################################
# IRSA — IAM Roles for Service Accounts
# Allows pods to assume scoped IAM roles without long-lived credentials.
###############################################################################

# VPC CNI IRSA — needed to manage ENIs/prefix delegations.
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

# EBS CSI IRSA — allows the EBS CSI driver to manage EBS volumes.
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

# AWS Load Balancer Controller IRSA — used in Phase 4.
module "aws_lb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name                              = "${var.project_name}-aws-lb-controller-irsa"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

###############################################################################
# Outputs — consumed by Phase 2 (ECR), Phase 3 (CI/CD), Phase 4 (Helm)
###############################################################################
output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded CA data for the cluster."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN — used for IRSA in Phase 4."
  value       = module.eks.oidc_provider_arn
}

output "aws_lb_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller (Phase 4)."
  value       = module.aws_lb_controller_irsa.iam_role_arn
}

output "configure_kubectl" {
  description = "Run this command to configure kubectl after apply."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
